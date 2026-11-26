-- One Firebase installation token belongs to a single current NAXA SERVICES account.
create unique index if not exists ns_push_tokens_global_fingerprint_uidx on public.ns_push_tokens(token_fingerprint);
create or replace function public.ns_register_bound_push_token(p_org_id uuid,p_member_id uuid,p_device_id uuid,p_session_id text,p_platform text,p_ciphertext text,p_iv text,p_fingerprint text,p_tail text)
returns uuid language plpgsql security definer set search_path='' as $fn$
declare v_id uuid;
begin
  perform 1 from public.ns_devices d join public.ns_accounts a on a.id=d.account_id join public.ns_members m on m.account_id=a.id join public.ns_organizations o on o.id=m.org_id join auth.sessions s on s.id::text=d.session_id and s.user_id=a.auth_user_id
  where d.id=p_device_id and d.session_id=p_session_id and d.platform=p_platform and d.revoked_at is null and a.status='active' and m.id=p_member_id and m.org_id=p_org_id and m.status='active' and o.status='active' and (s.not_after is null or s.not_after>now()) for update of d;
  if not found then raise exception 'NS_PUSH_SESSION_NOT_ACTIVE' using errcode='42501'; end if;
  insert into public.ns_push_tokens(org_id,member_id,device_id,platform,token_ciphertext,token_iv,token_fingerprint,token_tail,status,revoked_at,last_seen_at)
  values(p_org_id,p_member_id,p_device_id,p_platform,p_ciphertext,p_iv,p_fingerprint,p_tail,'active',null,now())
  on conflict(token_fingerprint) do update set org_id=excluded.org_id,member_id=excluded.member_id,device_id=excluded.device_id,platform=excluded.platform,token_ciphertext=excluded.token_ciphertext,token_iv=excluded.token_iv,token_tail=excluded.token_tail,status='active',revoked_at=null,last_seen_at=now()
  returning id into v_id;
  update public.ns_push_tokens set status='revoked',revoked_at=now() where device_id=p_device_id and id<>v_id and status='active';
  return v_id;
end $fn$;
create or replace function public.ns_live_push_tokens(p_org_id uuid,p_member_id uuid)
returns table(id uuid,token_ciphertext text,token_iv text) language sql security definer set search_path='' as $fn$
  select t.id,t.token_ciphertext,t.token_iv from public.ns_push_tokens t
  join public.ns_devices d on d.id=t.device_id and d.platform=t.platform
  join public.ns_accounts a on a.id=d.account_id
  join public.ns_members m on m.id=t.member_id and m.org_id=t.org_id and m.account_id=a.id
  join public.ns_organizations o on o.id=m.org_id
  join auth.sessions s on s.id::text=d.session_id and s.user_id=a.auth_user_id
  where t.org_id=p_org_id and t.member_id=p_member_id and t.status='active' and t.revoked_at is null and d.revoked_at is null and a.status='active' and m.status='active' and o.status='active' and (s.not_after is null or s.not_after>now())
  order by t.last_seen_at desc,t.id limit 20;
$fn$;
revoke all on function public.ns_register_bound_push_token(uuid,uuid,uuid,text,text,text,text,text,text),public.ns_live_push_tokens(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_register_bound_push_token(uuid,uuid,uuid,text,text,text,text,text,text),public.ns_live_push_tokens(uuid,uuid) to service_role;
