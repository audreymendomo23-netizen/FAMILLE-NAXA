-- Candidate only: apply to disposable DB; existing test retention ceiling only.
begin;
alter table public.wm_minutes_eligibility add column content_purged_at timestamptz;
-- Keep minimal audit receipts and version IDs; remove content, not historical proof.
create function public.wm_b6_minutes_purge_one()
returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare rid uuid; t timestamptz:=clock_timestamp();
begin
 select r.id into rid from public.wm_rooms r join public.wm_minutes_eligibility e on e.room_id=r.id
 where r.state->>'status'='ended' and e.retain_until<=t and e.content_purged_at is null
 order by e.retain_until,r.id for update of r skip locked limit 1;
 if not found then return null;end if;
 update public.wm_minutes_eligibility set snapshot='{}'::jsonb,content_purged_at=t where room_id=rid and retain_until<=t and content_purged_at is null;
 if not found then return null;end if;
 update public.wm_minutes_versions set body='[expired]',revoked_at=coalesce(revoked_at,t) where room_id=rid;
 update public.wm_minutes_recipients set revoked_at=coalesce(revoked_at,t) where version_id in (select id from public.wm_minutes_versions where room_id=rid);
 update public.wm_tasks set title='[expired]',evidence=null,state='cancelled',changed_at=t where room_id=rid;
 return rid;
end $wm$;
revoke all on function public.wm_b6_minutes_purge_one() from public,anon,authenticated;
grant execute on function public.wm_b6_minutes_purge_one() to service_role;
commit;
