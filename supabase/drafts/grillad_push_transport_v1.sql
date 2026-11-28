-- Candidate transport. Opt-in is bound to the explicit registration scope; old rows require re-enrolment.
begin;
alter table grillad_private.push_devices add column org uuid, add column site uuid, add column enrolled_at timestamptz;
create table grillad_private.push_attempts(
 id uuid primary key default gen_random_uuid(),device_id uuid not null references famille_private.account_devices(id),org uuid not null,site uuid not null,notice_id text not null,
 session_id uuid not null,registration_at timestamptz not null,created_at timestamptz not null default now(),
 status text not null default 'claimed' check(status in ('claimed','sending','accepted','invalid','refused','uncertain','skipped')),
 finished_at timestamptz, unique(device_id,org,site,notice_id)
);
alter table grillad_private.push_attempts enable row level security;
revoke all on grillad_private.push_attempts from public,anon,authenticated;
-- Preserve existing registration checks and response; save scope only after successful registration.
alter function grillad_private.push_register(uuid,uuid,text,text,boolean) rename to push_register_base;
revoke all on function grillad_private.push_register_base(uuid,uuid,text,text,boolean) from public,anon,authenticated;
create function grillad_private.push_register(p_org uuid,p_site uuid,p_token text,p_project text,p_enabled boolean) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare v jsonb;
begin
 v:=grillad_private.push_register_base(p_org,p_site,p_token,p_project,p_enabled);
 if p_enabled then
 update grillad_private.push_devices set org=p_org,site=p_site,enrolled_at=now() where user_id=auth.uid() and session_id=(auth.jwt()->>'session_id')::uuid and token=p_token;
 end if;
 return v;
end $$;
create or replace function public.grillad_push_register(p_org uuid,p_site uuid,p_token text,p_project text,p_enabled boolean) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.push_register(p_org,p_site,p_token,p_project,p_enabled)$$;
revoke all on function grillad_private.push_register(uuid,uuid,text,text,boolean) from public,anon,authenticated;
grant execute on function grillad_private.push_register(uuid,uuid,text,text,boolean) to authenticated;
-- Only the trusted scheduler invokes this helper. Identity is derived from DB, never caller parameters.
create function grillad_private.push_feed(p_device uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare d grillad_private.push_devices%rowtype;old_claims text:=current_setting('request.jwt.claims',true);old_sub text:=current_setting('request.jwt.claim.sub',true);v jsonb;
begin
 select p.* into d from grillad_private.push_devices p join famille_private.account_devices a on a.id=p.device_id and a.user_id=p.user_id and a.auth_session_id=p.session_id
 join auth.sessions s on s.id=p.session_id and s.user_id=p.user_id and s.tag='famille:grillad'
 where p.device_id=p_device and p.enabled and p.project_id='grillad' and p.enrolled_at is not null and p.org is not null and p.site is not null and a.status='active' and a.app_code='grillad' and a.platform='android';
 if not found then return null;end if;
 begin
 perform set_config('request.jwt.claim.sub',d.user_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',d.user_id,'session_id',d.session_id,'role','authenticated')::text,true);
 v:=grillad_private.notice_feed(d.org,d.site);
 exception when insufficient_privilege then v:=null;
 end;
 perform set_config('request.jwt.claim.sub',coalesce(old_sub,''),true);
 perform set_config('request.jwt.claims',coalesce(old_claims,''),true);
 return v;
end $$;
create function grillad_private.push_claim(p_limit integer) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare d grillad_private.push_devices%rowtype;v jsonb;n jsonb;a uuid;out jsonb:='[]';lim integer:=least(greatest(coalesce(p_limit,1),1),50);
begin
 -- Uncertain outcomes must never be silently retried; acceptance is not device delivery.
 update grillad_private.push_attempts set status='uncertain',finished_at=now() where status in ('claimed','sending') and created_at<now()-interval '10 minutes';
 for d in select * from grillad_private.push_devices where enabled and project_id='grillad' and enrolled_at is not null order by updated_at,device_id limit 500 loop
 exit when jsonb_array_length(out)>=lim;
 v:=grillad_private.push_feed(d.device_id);if v is null then continue;end if;
 for n in select x from jsonb_array_elements(v->'items') x where not coalesce((x->>'read')::boolean,false) and (x->>'at')::timestamptz>=greatest(d.enrolled_at,now()-interval '1 day') order by (x->>'at')::timestamptz loop
 a:=null;
 insert into grillad_private.push_attempts(device_id,org,site,notice_id,session_id,registration_at) values(d.device_id,d.org,d.site,n->>'id',d.session_id,d.enrolled_at) on conflict do nothing returning id into a;
 if a is not null then out:=out||jsonb_build_array(jsonb_build_object('id',a));end if;
 exit when jsonb_array_length(out)>=lim;
 end loop;
 end loop;
 return out;
end $$;
create function grillad_private.push_start(p_id uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare a grillad_private.push_attempts%rowtype;d grillad_private.push_devices%rowtype;v jsonb;
begin
 select * into a from grillad_private.push_attempts where id=p_id and status='claimed' for update;
 if not found then return null;end if;
 select * into d from grillad_private.push_devices where device_id=a.device_id and session_id=a.session_id and enrolled_at=a.registration_at and org=a.org and site=a.site and enabled and project_id='grillad';
 if found then v:=grillad_private.push_feed(d.device_id);end if;
 if v is null or not exists(select 1 from jsonb_array_elements(v->'items') x where x->>'id'=a.notice_id and not coalesce((x->>'read')::boolean,false)) then
 update grillad_private.push_attempts set status='skipped',finished_at=now() where id=a.id;return null;end if;
 update grillad_private.push_attempts set status='sending' where id=a.id;
 return jsonb_build_object('token',d.token);
end $$;
create function grillad_private.push_finish(p_id uuid,p_status text) returns boolean language plpgsql security definer set search_path=pg_catalog as $$
declare a grillad_private.push_attempts%rowtype;
begin
 if p_status not in ('accepted','invalid','refused','uncertain') or p_status is null then return false;end if;
 update grillad_private.push_attempts set status=p_status,finished_at=now() where id=p_id and status='sending' returning * into a;
 if not found then return false;end if;
 if p_status='invalid' then delete from grillad_private.push_devices where device_id=a.device_id and session_id=a.session_id and enrolled_at=a.registration_at;end if;
 return true;
end $$;
create function public.grillad_push_claim(p_limit integer) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.push_claim(p_limit)$$;
create function public.grillad_push_start(p_id uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $$select grillad_private.push_start(p_id)$$;
create function public.grillad_push_finish(p_id uuid,p_status text) returns boolean language sql security invoker set search_path=pg_catalog as $$select grillad_private.push_finish(p_id,p_status)$$;
revoke all on function grillad_private.push_feed(uuid),grillad_private.push_claim(integer),grillad_private.push_start(uuid),grillad_private.push_finish(uuid,text),public.grillad_push_claim(integer),public.grillad_push_start(uuid),public.grillad_push_finish(uuid,text) from public,anon,authenticated;
grant execute on function grillad_private.push_claim(integer),grillad_private.push_start(uuid),grillad_private.push_finish(uuid,text),public.grillad_push_claim(integer),public.grillad_push_start(uuid),public.grillad_push_finish(uuid,text) to service_role;
commit;
