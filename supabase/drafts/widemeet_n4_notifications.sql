-- Authorized, derived in-app inbox. No external push or delivery claim.
begin;
create table public.wm_notice_reads(
 workspace_id uuid not null references public.wm_workspaces(id),
 account_id uuid not null references public.wm_accounts(id),
 notice_key text not null check(length(notice_key) between 1 and 180),
 read_at timestamptz not null default clock_timestamp(),
 primary key(workspace_id,account_id,notice_key)
);
alter table public.wm_notice_reads enable row level security;
revoke all on public.wm_notice_reads from public,anon,authenticated;
grant select,insert on public.wm_notice_reads to service_role;
create function public.wm_notices(p_hash text,p_read text default null)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; role_name text; items jsonb; t timestamptz:=clock_timestamp();
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return null;end if;
 select role into role_name from public.wm_memberships where account_id=s.account_id and workspace_id=s.workspace_id and enabled;
 if not found then return null;end if;
 with notices as(
  select 'invite:'||r.id||':'||(r.state->>'scheduledMs') as k,'invitation' as kind,r.id as ref,r.state->>'title' as title,to_timestamp((r.state->>'scheduledMs')::double precision/1000) as due
  from public.wm_rooms r where r.workspace_id=s.workspace_id and r.state->>'status'='scheduled' and r.host_id<>s.account_id and exists(select 1 from public.wm_room_actor_for(p_hash,r.id))
   and exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=s.account_id::text and p->>'response' in ('pending','maybe') and p->>'excluded'='false')
  union all
  select 'reminder:'||r.id||':'||(r.state->>'scheduledMs'),'meeting_reminder',r.id,r.state->>'title',to_timestamp((r.state->>'scheduledMs')::double precision/1000)
  from public.wm_rooms r where r.workspace_id=s.workspace_id and r.state->>'status'='scheduled' and to_timestamp((r.state->>'scheduledMs')::double precision/1000) between t and t+interval '24 hours' and exists(select 1 from public.wm_room_actor_for(p_hash,r.id))
   and exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=s.account_id::text and p->>'response'='accepted' and p->>'excluded'='false')
  union all
  select 'minutes:'||v.id,'minutes_published',r.id,r.state->>'title',v.published_at
  from public.wm_minutes_recipients x join public.wm_minutes_versions v on v.id=x.version_id and v.revoked_at is null and v.published_at is not null join public.wm_minutes_eligibility e on e.room_id=v.room_id and e.retain_until>t join public.wm_rooms r on r.id=v.room_id
  where x.account_id=s.account_id and x.revoked_at is null and r.workspace_id=s.workspace_id
  union all
  select 'task:'||k.id||':'||k.revision,case when k.state='done' then 'task_done' when k.state='submitted' then 'task_review' when k.due_at<t then 'task_overdue' else 'task_assigned' end,k.id,k.title,k.due_at
  from public.wm_tasks k join public.wm_rooms r on r.id=k.room_id and r.workspace_id=s.workspace_id join public.wm_minutes_eligibility e on e.room_id=k.room_id and e.retain_until>t join public.wm_minutes_versions v on v.id=k.version_id and v.revoked_at is null
  where k.state<>'cancelled' and ((k.assignee_id=s.account_id and exists(select 1 from public.wm_minutes_recipients x where x.version_id=k.version_id and x.account_id=s.account_id and x.revoked_at is null)) or (r.host_id=s.account_id and role_name in ('owner','promoteur','manager') and k.state='submitted'))
  union all
  select 'subscription:'||e.workspace_id||':'||extract(epoch from e.valid_until)::bigint,'subscription_expiring',e.workspace_id,null,e.valid_until
  from public.wm_room_entitlements e where e.workspace_id=s.workspace_id and e.enabled and role_name='promoteur' and e.valid_until between t and t+interval '72 hours'
 ), visible as (
  select n.k,n.kind,n.ref,n.title,n.due,r.read_at from notices n left join public.wm_notice_reads r on r.workspace_id=s.workspace_id and r.account_id=s.account_id and r.notice_key=n.k
  where n.k is not null and n.due is not null order by (r.read_at is not null),n.due,n.k limit 100
 )
 select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) into items from visible v;
 if p_read is not null then
  if length(p_read)>180 or not exists(select 1 from jsonb_array_elements(items) x where x->>'k'=p_read) then return null;end if;
  insert into public.wm_notice_reads(workspace_id,account_id,notice_key) values(s.workspace_id,s.account_id,p_read) on conflict do nothing;
  return jsonb_build_object('read',true);
 end if;
 return jsonb_build_object('items',items);
end $wm$;
revoke all on function public.wm_notices(text,text) from public,anon,authenticated;
grant execute on function public.wm_notices(text,text) to service_role;

-- B2.9: adapted from the NAXA SERVICES per-installation notification ledger.
-- No account identifiers, provider secrets, content or read receipts are accepted from the client.
create table public.wm_push_devices(
 session_id uuid primary key references public.wm_device_sessions(id),
 account_id uuid not null references public.wm_accounts(id),workspace_id uuid not null references public.wm_workspaces(id),
 installation_id uuid not null,platform text not null check(platform in ('android','web')),
 fingerprint text not null check(length(fingerprint)=64 and translate(fingerprint,'0123456789abcdef','')=''),
 ciphertext text not null check(length(ciphertext) between 24 and 6000),iv text not null check(length(iv)=16),
 registered_at timestamptz not null default clock_timestamp(),revoked_at timestamptz
);
create unique index wm_push_device_active_token on public.wm_push_devices(fingerprint) where revoked_at is null;
create unique index wm_push_device_active_installation on public.wm_push_devices(installation_id) where revoked_at is null;
create table public.wm_push_deliveries(
 id uuid primary key default gen_random_uuid(),account_id uuid not null,workspace_id uuid not null,installation_id uuid not null,
 notice_key text not null check(length(notice_key) between 1 and 180),session_id uuid not null references public.wm_push_devices(session_id),
 status text not null check(status in ('claimed','accepted','rejected','uncertain','cancelled')),
 claim_token uuid not null default gen_random_uuid(),claimed_at timestamptz not null default clock_timestamp(),finished_at timestamptz,
 provider_reference text,error_code text,
 unique(account_id,workspace_id,installation_id,notice_key)
);
alter table public.wm_push_devices enable row level security;
alter table public.wm_push_deliveries enable row level security;
revoke all on public.wm_push_devices,public.wm_push_deliveries from public,anon,authenticated;
grant select,insert,update on public.wm_push_devices,public.wm_push_deliveries to service_role;
create function public.wm_push_device_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; existing public.wm_push_devices%rowtype;
begin
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 select * into a from public.wm_session_context(p_hash) where not password_change_required;
 if not found then return null;end if;
 if p_action='status' then return jsonb_build_object('enabled',exists(select 1 from public.wm_push_devices d where d.session_id=a.session_id and d.revoked_at is null));end if;
 if p_action='revoke' then update public.wm_push_devices set revoked_at=coalesce(revoked_at,clock_timestamp()) where session_id=a.session_id;return jsonb_build_object('revoked',true);end if;
 if p_action<>'register' or coalesce(p_data->>'platform','') not in ('android','web') then return null;end if;
 select * into existing from public.wm_push_devices where fingerprint=p_data->>'fingerprint' and revoked_at is null;
 if found and existing.installation_id<>a.installation_id then return null;end if;
 update public.wm_push_devices set revoked_at=coalesce(revoked_at,clock_timestamp()) where installation_id=a.installation_id and session_id<>a.session_id and revoked_at is null;
 insert into public.wm_push_devices(session_id,account_id,workspace_id,installation_id,platform,fingerprint,ciphertext,iv)
 values(a.session_id,a.account_id,a.workspace_id,a.installation_id,p_data->>'platform',p_data->>'fingerprint',p_data->>'ciphertext',p_data->>'iv')
 on conflict(session_id) do update set platform=excluded.platform,fingerprint=excluded.fingerprint,ciphertext=excluded.ciphertext,iv=excluded.iv,revoked_at=null,registered_at=clock_timestamp();
 return jsonb_build_object('enabled',true);
exception when unique_violation or check_violation or not_null_violation then return null;
end $wm$;
-- A push belongs to the current authorized session and current unread notice.
-- No implicit access after logout, removal, workspace switch or expiration.
create function public.wm_push_claim(p_limit integer default 25)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare d record;n jsonb;row_id uuid;claim uuid;outcome jsonb:='[]'::jsonb;
begin
 if p_limit is null or p_limit not between 1 and 100 then return null;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-push-claim-v1',0));
 update public.wm_push_deliveries set status='uncertain',finished_at=clock_timestamp(),error_code='CLAIM_EXPIRED' where status='claimed' and claimed_at<clock_timestamp()-interval '5 minutes';
 for d in select t.*,s.token_hash from public.wm_push_devices t join public.wm_device_sessions s on s.id=t.session_id
 where t.revoked_at is null and s.revoked_at is null and s.expires_at>clock_timestamp()
 and exists(select 1 from public.wm_session_context(s.token_hash) a where not a.password_change_required)
 order by t.registered_at,t.session_id limit 100
 loop
  for n in select x from jsonb_array_elements(coalesce(public.wm_notices(d.token_hash)->'items','[]'::jsonb)) x where x->>'read_at' is null
  loop
   row_id:=null;
   insert into public.wm_push_deliveries(account_id,workspace_id,installation_id,notice_key,session_id,status)
   values(d.account_id,d.workspace_id,d.installation_id,n->>'k',d.session_id,'claimed')
   on conflict(account_id,workspace_id,installation_id,notice_key) do nothing returning id,claim_token into row_id,claim;
   if row_id is not null then outcome:=outcome||jsonb_build_array(jsonb_build_object('id',row_id,'claim_token',claim));end if;
   if jsonb_array_length(outcome)>=p_limit then return jsonb_build_object('items',outcome);end if;
  end loop;
 end loop;
 return jsonb_build_object('items',outcome);
end $wm$;
create function public.wm_push_target(p_id uuid,p_claim uuid)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare d record;
begin
 select p.*,t.ciphertext,t.iv,t.fingerprint,s.token_hash into d
 from public.wm_push_deliveries p join public.wm_push_devices t on t.session_id=p.session_id and t.revoked_at is null
 join public.wm_device_sessions s on s.id=t.session_id and s.revoked_at is null and s.expires_at>clock_timestamp()
 where p.id=p_id and p.claim_token=p_claim and p.status='claimed' and p.claimed_at>clock_timestamp()-interval '5 minutes'
 and p.account_id=t.account_id and p.workspace_id=t.workspace_id and p.installation_id=t.installation_id
 and exists(select 1 from public.wm_session_context(s.token_hash) a where not a.password_change_required);
 if not found or not exists(select 1 from jsonb_array_elements(coalesce(public.wm_notices(d.token_hash)->'items','[]'::jsonb)) x where x->>'k'=d.notice_key and x->>'read_at' is null) then return null;end if;
 return jsonb_build_object('ciphertext',d.ciphertext,'iv',d.iv,'fingerprint',d.fingerprint);
end $wm$;
create function public.wm_push_finish(p_id uuid,p_claim uuid,p_status text,p_reference text default null,p_error text default null,p_revoke boolean default false)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare sid uuid;
begin
 if p_status not in ('accepted','rejected','uncertain','cancelled') or (p_status='accepted')<>(p_reference is not null) or (p_status='accepted')=(p_error is not null) or length(coalesce(p_reference,''))>512 or length(coalesce(p_error,''))>100 then return false;end if;
 update public.wm_push_deliveries set status=p_status,provider_reference=p_reference,error_code=p_error,finished_at=clock_timestamp()
 where id=p_id and claim_token=p_claim and status='claimed' returning session_id into sid;
 if not found then return false;end if;
 if p_revoke and p_status='rejected' and p_error in ('UNREGISTERED','SENDER_ID_MISMATCH') then update public.wm_push_devices set revoked_at=coalesce(revoked_at,clock_timestamp()) where session_id=sid;end if;
 return true;
end $wm$;
revoke all on function public.wm_push_device_action(text,text,jsonb),public.wm_push_claim(integer),public.wm_push_target(uuid,uuid),public.wm_push_finish(uuid,uuid,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.wm_push_device_action(text,text,jsonb),public.wm_push_claim(integer),public.wm_push_target(uuid,uuid),public.wm_push_finish(uuid,uuid,text,text,text,boolean) to service_role;
commit;
