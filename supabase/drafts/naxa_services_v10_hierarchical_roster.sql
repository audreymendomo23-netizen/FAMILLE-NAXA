begin;
-- Planning candidate. Install only in disposable qualification until UI and delivery pass.
create function public.ns_roster_enabled(p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and public.ns_current_member_id(p_org) is not null and exists(select 1 from public.ns_organizations o where o.id=p_org and o.status='active' and o.business_mode in ('single_site_multi_workstation','multi_site_network'))
$$;
create function public.ns_roster_rank(p_role text) returns integer language sql immutable set search_path='' as $$
 select case p_role when 'promoter' then 40 when 'network_manager' then 30 when 'site_manager' then 20 when 'workstation_manager' then 10 else 0 end
$$;
create function public.ns_roster_can_manage(p_org uuid,p_site uuid,p_post uuid,p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.ns_roster_enabled(p_org) and public.ns_erp_access_reason(p_org)<>'blocked' and exists(
 select 1 from public.ns_members a join public.ns_members t on t.org_id=a.org_id
 join public.ns_sites s on s.org_id=a.org_id and s.id=p_site and s.status='active'
 where a.id=public.ns_current_member_id(p_org) and a.org_id=p_org and t.id=p_member and t.status='active'
 and public.ns_roster_rank(a.role_code)>public.ns_roster_rank(t.role_code)
 and (p_post is null or exists(select 1 from public.ns_workstations w where w.id=p_post and w.org_id=p_org and w.site_id=p_site and w.status='active'))
 and exists(select 1 from public.ns_member_scopes x where x.org_id=p_org and x.member_id=a.id and x.can_manage and (
 (a.role_code='promoter' and x.scope_type='organization')
 or (a.role_code in ('network_manager','site_manager') and x.scope_type='site' and x.site_id=p_site)
 or (a.role_code='workstation_manager' and p_post is not null and x.scope_type='workstation' and x.site_id=p_site and x.workstation_id=p_post)))
 and exists(select 1 from public.ns_member_scopes x where x.org_id=p_org and x.member_id=t.id and (x.can_operate or x.can_manage) and (
 x.scope_type='organization' or (x.scope_type='site' and x.site_id=p_site) or (x.scope_type='workstation' and x.site_id=p_site and x.workstation_id=p_post))))
$$;
create function public.ns_roster_can_read(p_org uuid,p_site uuid,p_post uuid,p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.ns_roster_enabled(p_org) and (p_member=public.ns_current_member_id(p_org) or public.ns_roster_can_manage(p_org,p_site,p_post,p_member))
$$;
revoke all on function public.ns_roster_enabled(uuid),public.ns_roster_rank(text),public.ns_roster_can_manage(uuid,uuid,uuid,uuid),public.ns_roster_can_read(uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_roster_enabled(uuid),public.ns_roster_can_manage(uuid,uuid,uuid,uuid),public.ns_roster_can_read(uuid,uuid,uuid,uuid) to authenticated;
create table public.ns_roster_shifts(
 id uuid primary key, org_id uuid not null, site_id uuid not null, workstation_id uuid, member_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null, planned_break_minutes integer not null default 0,
 tolerance_minutes integer not null default 10, status text not null check(status in ('published','cancelled')),
 revision bigint not null check(revision>0), updated_by uuid not null, updated_at timestamptz not null,
 change_reason text not null check(length(trim(change_reason)) between 1 and 500),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(workstation_id,site_id,org_id) references public.ns_workstations(id,site_id,org_id),
 foreign key(member_id,org_id) references public.ns_members(id,org_id),
 foreign key(updated_by,org_id) references public.ns_members(id,org_id),
 check(ends_at>starts_at and ends_at<=starts_at+interval '24 hours'),
 check(planned_break_minutes>=0 and planned_break_minutes<extract(epoch from ends_at-starts_at)/60),
 check(tolerance_minutes between 0 and 120));
create index ns_roster_member_period on public.ns_roster_shifts(org_id,member_id,starts_at,ends_at) where status='published';
create table public.ns_roster_revisions(
 shift_id uuid not null references public.ns_roster_shifts(id), revision bigint not null,
 org_id uuid not null, site_id uuid not null, workstation_id uuid, member_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null, planned_break_minutes integer not null,
 tolerance_minutes integer not null,status text not null,updated_by uuid not null,updated_at timestamptz not null,change_reason text not null,
 primary key(shift_id,revision));
create table public.ns_roster_acknowledgements(
 shift_id uuid not null, revision bigint not null, org_id uuid not null, site_id uuid not null, workstation_id uuid, member_id uuid not null,
 acknowledged_at timestamptz not null default clock_timestamp(), primary key(shift_id,revision),
 foreign key(shift_id,revision) references public.ns_roster_revisions(shift_id,revision));
alter table public.ns_roster_shifts enable row level security;
alter table public.ns_roster_revisions enable row level security;
alter table public.ns_roster_acknowledgements enable row level security;
revoke all on public.ns_roster_shifts,public.ns_roster_revisions,public.ns_roster_acknowledgements from public,anon,authenticated;
grant select on public.ns_roster_shifts,public.ns_roster_revisions,public.ns_roster_acknowledgements to authenticated;
create policy ns_roster_shift_read on public.ns_roster_shifts for select to authenticated using(public.ns_roster_can_read(org_id,site_id,workstation_id,member_id));
create policy ns_roster_revision_read on public.ns_roster_revisions for select to authenticated using(public.ns_roster_can_read(org_id,site_id,workstation_id,member_id));
create policy ns_roster_ack_read on public.ns_roster_acknowledgements for select to authenticated using(public.ns_roster_can_read(org_id,site_id,workstation_id,member_id));
create function public.ns_publish_roster_shift(p_id uuid,p_org uuid,p_site uuid,p_post uuid,p_member uuid,p_starts timestamptz,p_ends timestamptz,p_break integer,p_tolerance integer,p_status text,p_expected_revision bigint,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.ns_roster_shifts%rowtype; old public.ns_roster_shifts%rowtype; v_notification uuid; v_locale text; v_message jsonb; v_actor uuid;
begin
 if p_id is null or p_expected_revision is null or p_status not in ('published','cancelled') or p_reason is null or length(trim(p_reason)) not between 1 and 500 then raise exception 'NS_ROSTER_INVALID'; end if;
 if not public.ns_roster_can_manage(p_org,p_site,p_post,p_member) then raise exception 'NS_ROSTER_FORBIDDEN'; end if;
 v_actor:=public.ns_current_member_id(p_org);
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_member::text||':roster',0));
 select * into old from public.ns_roster_shifts where id=p_id for update;
 if found then
  if (old.org_id,old.member_id) is distinct from (p_org,p_member) or not public.ns_roster_can_manage(old.org_id,old.site_id,old.workstation_id,old.member_id) then raise exception 'NS_ROSTER_FORBIDDEN'; end if;
  -- A lost response may be retried only with the identical command by the same actor.
  if old.revision=p_expected_revision+1 and old.updated_by=v_actor and
     (old.site_id,old.workstation_id,old.starts_at,old.ends_at,old.planned_break_minutes,old.tolerance_minutes,old.status,old.change_reason)
     is not distinct from (p_site,p_post,p_starts,p_ends,p_break,p_tolerance,p_status,trim(p_reason)) then
   select n.id into v_notification from public.ns_notification_outbox n where n.org_id=p_org and n.recipient_member_id=p_member and n.idempotency_key='staff-schedule:'||p_id::text||':'||old.revision::text;
   if v_notification is null then raise exception 'NS_ROSTER_RECEIPT_MISSING'; end if;
   return jsonb_build_object('id',old.id,'revision',old.revision,'status',old.status,'notification_id',v_notification);
  end if;
  if old.revision<>p_expected_revision then raise exception 'NS_ROSTER_REVISION_CONFLICT'; end if;
  if old.status='cancelled' then raise exception 'NS_ROSTER_CANCELLED'; end if;
  if p_status='cancelled' and (old.site_id,old.workstation_id,old.starts_at,old.ends_at,old.planned_break_minutes,old.tolerance_minutes) is distinct from (p_site,p_post,p_starts,p_ends,p_break,p_tolerance) then raise exception 'NS_ROSTER_CANCEL_CHANGE'; end if;
 else
  if p_expected_revision<>0 or p_status<>'published' then raise exception 'NS_ROSTER_REVISION_CONFLICT'; end if;
 end if;
 if p_starts is null or p_ends is null or p_ends<=p_starts or p_ends>p_starts+interval '24 hours' or p_break is null or p_break<0 or p_break>=extract(epoch from p_ends-p_starts)/60 or p_tolerance is null or p_tolerance not between 0 and 120 then raise exception 'NS_ROSTER_TIME_INVALID'; end if;
 if p_status='published' and exists(select 1 from public.ns_roster_shifts s where s.org_id=p_org and s.member_id=p_member and s.id<>p_id and s.status='published' and s.starts_at<p_ends and p_starts<s.ends_at) then raise exception 'NS_ROSTER_OVERLAP'; end if;
 insert into public.ns_roster_shifts(id,org_id,site_id,workstation_id,member_id,starts_at,ends_at,planned_break_minutes,tolerance_minutes,status,revision,updated_by,updated_at,change_reason)
 values(p_id,p_org,p_site,p_post,p_member,p_starts,p_ends,p_break,p_tolerance,p_status,p_expected_revision+1,v_actor,clock_timestamp(),trim(p_reason))
 on conflict(id) do update set site_id=excluded.site_id,workstation_id=excluded.workstation_id,starts_at=excluded.starts_at,ends_at=excluded.ends_at,planned_break_minutes=excluded.planned_break_minutes,tolerance_minutes=excluded.tolerance_minutes,status=excluded.status,revision=excluded.revision,updated_by=excluded.updated_by,updated_at=excluded.updated_at,change_reason=excluded.change_reason
 where ns_roster_shifts.org_id=excluded.org_id and ns_roster_shifts.member_id=excluded.member_id and ns_roster_shifts.revision=p_expected_revision
 returning * into v;
 if not found then raise exception 'NS_ROSTER_REVISION_CONFLICT'; end if;
 insert into public.ns_roster_revisions select v.id,v.revision,v.org_id,v.site_id,v.workstation_id,v.member_id,v.starts_at,v.ends_at,v.planned_break_minutes,v.tolerance_minutes,v.status,v.updated_by,v.updated_at,v.change_reason;
 select coalesce(m.preferred_locale,o.default_locale,'fr') into v_locale from public.ns_members m join public.ns_organizations o on o.id=m.org_id where m.id=p_member;
 v_message:=case v_locale when 'en' then jsonb_build_object('title','Work schedule updated','body','Open your schedule to review and acknowledge the latest change.')
 when 'ff-CM' then jsonb_build_object('title','Feere golle hesɗitinaama','body','Uddit feere golle maa ngam ƴeewtaade baylugol kesol.')
 else jsonb_build_object('title','Planning de service mis à jour','body','Consultez votre planning et confirmez la prise de connaissance.') end;
 v_message:=v_message||jsonb_build_object('route','/team','shift_id',p_id,'revision',v.revision);
 insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted)
 values(p_org,p_site,p_member,'push','staff_schedule.updated','staff-schedule:'||p_id::text||':'||v.revision::text,v_message)
 returning id into v_notification;
 -- In-app visible even without a push token. Push worker later updates the SAME inbox record.
 insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
 values(p_org,p_site,p_member,v_notification,'staff_schedule.updated',v_message,'sent',clock_timestamp());
 return jsonb_build_object('id',v.id,'revision',v.revision,'status',v.status,'notification_id',v_notification);
end $$;
create function public.ns_ack_roster_shift(p_id uuid,p_revision bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.ns_roster_shifts%rowtype;
begin
 select * into v from public.ns_roster_shifts where id=p_id for share;
 if not found or not public.ns_roster_enabled(v.org_id) or public.ns_current_member_id(v.org_id) is distinct from v.member_id then raise exception 'NS_ROSTER_FORBIDDEN'; end if;
 if v.revision is distinct from p_revision then raise exception 'NS_ROSTER_REVISION_CONFLICT'; end if;
 insert into public.ns_roster_acknowledgements(shift_id,revision,org_id,site_id,workstation_id,member_id) values(v.id,v.revision,v.org_id,v.site_id,v.workstation_id,v.member_id) on conflict do nothing;
 return jsonb_build_object('id',v.id,'revision',v.revision,'acknowledged',true);
end $$;
revoke all on function public.ns_publish_roster_shift(uuid,uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,integer,text,bigint,text),public.ns_ack_roster_shift(uuid,bigint) from public,anon,authenticated;
grant execute on function public.ns_publish_roster_shift(uuid,uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,integer,text,bigint,text),public.ns_ack_roster_shift(uuid,bigint) to authenticated;

rollback;
