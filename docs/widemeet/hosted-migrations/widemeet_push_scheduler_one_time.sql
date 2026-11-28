-- Authorized WideMeet hosted scheduler; no reusable credential travels through pg_net.
begin;
create table public.wm_push_scheduler_tickets (
 id uuid primary key default gen_random_uuid(),
 token_hash text not null unique check(token_hash ~ '^[a-f0-9]{64}$'),
 mode text not null check(mode in ('preflight','dispatch')),
 issued_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null,
 used_at timestamptz,
 outcome text check(outcome in ('configuration_invalid','oauth_failed','oauth_verified','disabled','dispatch_failed','dispatch_attention','dispatch_completed'))
);
alter table public.wm_push_scheduler_tickets enable row level security;
revoke all on public.wm_push_scheduler_tickets from public,anon,authenticated;
grant select,insert,update,delete on public.wm_push_scheduler_tickets to service_role;
create function public.wm_push_scheduler_take(p_hash text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare t public.wm_push_scheduler_tickets%rowtype;
begin
 update public.wm_push_scheduler_tickets set used_at=clock_timestamp()
 where token_hash=p_hash and used_at is null and expires_at>clock_timestamp()
 returning * into t;
 if not found then return null; end if;
 return jsonb_build_object('id',t.id,'mode',t.mode);
end $$;
create function public.wm_push_scheduler_finish(p_id uuid,p_outcome text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
begin
 update public.wm_push_scheduler_tickets set outcome=p_outcome where id=p_id and used_at is not null and outcome is null;
 return found;
end $$;
create function public.wm_push_scheduler_enqueue(p_mode text) returns bigint language plpgsql security invoker set search_path=pg_catalog,public as $$
declare ticket text;
begin
 if p_mode not in ('preflight','dispatch') then raise exception 'invalid_mode'; end if;
 if not pg_try_advisory_xact_lock(hashtext('widemeet-push-scheduler')) then return null; end if;
 delete from public.wm_push_scheduler_tickets where issued_at<clock_timestamp()-interval '7 days';
 if exists(select 1 from public.wm_push_scheduler_tickets where expires_at>clock_timestamp() and outcome is null) then return null; end if;
 if p_mode='dispatch' and (not exists(select 1 from public.wm_push_devices where revoked_at is null) or exists(select 1 from public.wm_push_scheduler_tickets where mode='dispatch' and issued_at>clock_timestamp()-interval '50 seconds')) then return null; end if;
 ticket:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.wm_push_scheduler_tickets(token_hash,mode,expires_at) values(encode(extensions.digest(ticket,'sha256'),'hex'),p_mode,clock_timestamp()+interval '90 seconds');
 return net.http_post(url:='https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/widemeet-push-scheduler',headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||ticket),body:='{}'::jsonb,timeout_milliseconds:=75000);
end $$;
revoke all on function public.wm_push_scheduler_take(text),public.wm_push_scheduler_finish(uuid,text),public.wm_push_scheduler_enqueue(text) from public,anon,authenticated;
revoke all on function public.wm_push_scheduler_enqueue(text) from service_role;
grant execute on function public.wm_push_scheduler_take(text),public.wm_push_scheduler_finish(uuid,text) to service_role;
-- Leave the schedule inactive until the OAuth preflight is successful.
select cron.schedule('widemeet-push-minute','* * * * *',$job$select public.wm_push_scheduler_enqueue('dispatch')$job$);
select cron.alter_job((select jobid from cron.job where jobname='widemeet-push-minute'),active:=false);
commit;
