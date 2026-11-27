-- Registered-account invitation, single recipient, single room, no tenant membership.
-- Token is high entropy, hash only at rest. Lobby required before issue.
begin;
create function public.wm_external_invite(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record;a record;r public.wm_rooms%rowtype;g public.wm_external_guests%rowtype;rid uuid;gid uuid;target_id uuid;digest text;cap integer;deadline timestamptz;t timestamptz:=clock_timestamp();next_state jsonb;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required or jsonb_typeof(p_data) is distinct from 'object' then return null;end if;
 perform 1 from public.wm_accounts where id=s.account_id and enabled and not password_change_required for share;if not found then return null;end if;
 perform 1 from public.wm_workspaces where id=s.workspace_id and enabled for share;if not found then return null;end if;
 perform 1 from public.wm_memberships where account_id=s.account_id and workspace_id=s.workspace_id and enabled for share;if not found then return null;end if;
 perform 1 from public.wm_device_sessions where id=s.session_id and revoked_at is null and expires_at>clock_timestamp() for share;if not found then return null;end if;
 if not exists(select 1 from public.wm_session_context(p_hash)) then return null;end if;
 begin rid:=(p_data->>'room_id')::uuid;gid:=(p_data->>'invite_id')::uuid;exception when invalid_text_representation then return null;end;
 digest:=p_data->>'digest';
 if p_action='redeem' then
  if digest is null or digest!~'^[a-f0-9]{64}$' then return null;end if;
  select * into g from public.wm_external_guests where token_hash=digest and account_id=s.account_id and revoked_at is null;
  if not found then return null;end if;
  rid:=g.room_id;gid:=g.id;
  select * into r from public.wm_rooms where id=rid for update;
  if not found or r.state->>'lobbyRequired' is distinct from 'true' or r.state->>'status' not in ('scheduled','open') or (r.state->>'hardEndMs')::bigint<=floor(extract(epoch from t)*1000)::bigint or r.state->>'status'='open' and ((r.state->>'endMs')::bigint<=floor(extract(epoch from t)*1000)::bigint or r.state->>'admissionLocked'='true') then return null;end if;
  select * into g from public.wm_external_guests where id=gid and account_id=s.account_id and token_hash=digest and revoked_at is null for update;
  if not found or exists(select 1 from public.wm_memberships where workspace_id=r.workspace_id and account_id=s.account_id) then return null;end if;
  if not exists(select 1 from public.wm_workspaces w join public.wm_memberships hm on hm.workspace_id=w.id and hm.account_id=r.host_id and hm.enabled and hm.role in ('owner','promoteur','manager') join public.wm_accounts ha on ha.id=r.host_id and ha.enabled and not ha.password_change_required where w.id=r.workspace_id and w.enabled and (exists(select 1 from public.wm_room_entitlements e where e.workspace_id=w.id and e.enabled and e.valid_until>t and w.kind='enterprise') or exists(select 1 from public.wm_paid_passes p where p.consumed_room_id=r.id and p.valid_until>t and w.kind='individual'))) then return null;end if;
  if g.redeemed_at is not null then
   if exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=s.account_id::text and p->>'excluded'='false') then return jsonb_build_object('room_id',rid);end if;
   return null;
  end if;
  if g.expires_at<=t or jsonb_array_length(r.state->'participants')>=coalesce((r.state->>'capacity')::integer,20) or exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=s.account_id::text) then return null;end if;
  update public.wm_external_guests set redeemed_at=t where id=gid;
  next_state:=jsonb_set(r.state,'{participants}',r.state->'participants'||jsonb_build_array(jsonb_build_object('memberId',s.account_id,'response','accepted','excluded',false,'chat',true,'mic',true,'screen',false,'consent',false,'lobbyStatus',case when r.state->>'status'='open' then 'waiting' else 'pending' end)));
  update public.wm_rooms set revision=r.revision+1,state=next_state||jsonb_build_object('revision',r.revision+1,'recording','off','events',coalesce(next_state->'events','[]'::jsonb)||jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'actor',s.account_id,'action','external_redeem','payload',jsonb_build_array('external_redeem',null,null,r.revision)::text,'at',floor(extract(epoch from t)*1000)::bigint))) where id=rid;
  return jsonb_build_object('room_id',rid);
 end if;
 select * into a from public.wm_lock_room_actor_for(p_hash,rid);
 if not found or a.role not in ('owner','promoteur','manager') then return null;end if;
 select * into r from public.wm_rooms where id=rid and workspace_id=a.workspace_id and host_id=s.account_id for update;
 if not found then return null;end if;
 if p_action='list' then
  return jsonb_build_object('items',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'name',ac.display_name,'expires_at',x.expires_at,'redeemed_at',x.redeemed_at,'revoked_at',x.revoked_at) order by x.created_at desc) from public.wm_external_guests x join public.wm_accounts ac on ac.id=x.account_id where x.room_id=rid),'[]'::jsonb));
 end if;
 if r.state->>'status' not in ('scheduled','open') then return null;end if;
 if p_action='issue' then
  if r.state->>'lobbyRequired' is distinct from 'true' or gid is null or digest is null or digest!~'^[a-f0-9]{64}$' or coalesce(p_data->>'login_id','')!~'^WM-[A-Z0-9]{6,64}$' then return null;end if;
  select id into target_id from public.wm_accounts where login_id=p_data->>'login_id' and enabled and not password_change_required;
  if not found or target_id=s.account_id or exists(select 1 from public.wm_memberships where workspace_id=r.workspace_id and account_id=target_id) then return null;end if;
  select * into g from public.wm_external_guests where id=gid;
  if found then
   if g.room_id=rid and g.account_id=target_id and g.token_hash=digest and g.revoked_at is null and g.expires_at>t then return jsonb_build_object('id',gid,'expires_at',g.expires_at);end if;
   return null;
  end if;
  cap:=coalesce((r.state->>'capacity')::integer,20);
  if jsonb_array_length(r.state->'participants')+(select count(*) from public.wm_external_guests where room_id=rid and redeemed_at is null and revoked_at is null and expires_at>t)>=cap then return null;end if;
  deadline:=least(t+interval '24 hours',to_timestamp((r.state->>'hardEndMs')::double precision/1000));
  if deadline<=t then return null;end if;
  insert into public.wm_external_guests(id,room_id,account_id,token_hash,expires_at) values(gid,rid,target_id,digest,deadline) on conflict do nothing;
  if not found then return null;end if;
  return jsonb_build_object('id',gid,'expires_at',deadline);
 elsif p_action='revoke' then
  select * into g from public.wm_external_guests where id=gid and room_id=rid for update;if not found then return null;end if;
  if g.revoked_at is not null then return jsonb_build_object('revoked',true);end if;
  update public.wm_external_guests set revoked_at=t where id=gid;
  if g.redeemed_at is not null then
   select jsonb_set(r.state,'{participants}',coalesce(jsonb_agg(case when p->>'memberId'=g.account_id::text then p||jsonb_build_object('excluded',true,'consent',false,'moderatorPermissions','[]'::jsonb) else p end order by ord),'[]'::jsonb)) into next_state from jsonb_array_elements(r.state->'participants') with ordinality as x(p,ord);
   update public.wm_rooms set revision=r.revision+1,state=next_state||jsonb_build_object('revision',r.revision+1,'recording','off','events',coalesce(next_state->'events','[]'::jsonb)||jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'actor',s.account_id,'action','external_revoke','payload',jsonb_build_array('external_revoke',g.account_id,null,r.revision)::text,'at',floor(extract(epoch from t)*1000)::bigint))) where id=rid;
  end if;
  return jsonb_build_object('revoked',true);
 end if;
 return null;
end $wm$;
revoke all on function public.wm_external_invite(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_external_invite(text,text,jsonb) to service_role;
commit;
