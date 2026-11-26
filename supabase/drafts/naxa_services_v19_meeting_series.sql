begin;
-- v19: bounded recurring series; all occurrences created atomically using the qualified v18 path.
create table public.ns_meeting_series(
 id uuid primary key,org_id uuid not null,site_id uuid not null,host_member_id uuid not null,
 frequency text not null check(frequency in ('daily','weekly')),occurrence_count integer not null check(occurrence_count between 2 and 12),
 request_payload jsonb not null,created_at timestamptz not null default now(),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(host_member_id,org_id) references public.ns_members(id,org_id));
alter table public.ns_meeting_series enable row level security;
revoke all on public.ns_meeting_series from public,anon,authenticated;
alter table public.ns_internal_meetings add column series_id uuid references public.ns_meeting_series(id),add column series_occurrence integer;
alter table public.ns_internal_meetings add constraint ns_meeting_series_pair check((series_id is null and series_occurrence is null) or (series_id is not null and series_occurrence between 1 and 12));
create unique index ns_meeting_series_occurrence on public.ns_internal_meetings(series_id,series_occurrence) where series_id is not null;
-- Attach series metadata at INSERT, not UPDATE: the existing revision/history trigger remains unchanged.
create function public.ns_meeting_attach_series() returns trigger language plpgsql security definer set search_path='' as $f$
declare s public.ns_meeting_series%rowtype; n integer;
begin
 for s in select * from public.ns_meeting_series where org_id=new.org_id and site_id=new.site_id and host_member_id=new.host_member_id and id::text=current_setting('ns.meeting_series_id',true) loop
  for n in 1..s.occurrence_count loop
   if new.id=md5(s.id::text||':'||n)::uuid then new.series_id:=s.id;new.series_occurrence:=n;return new;end if;
  end loop;
 end loop;
 return new;
end $f$;
revoke all on function public.ns_meeting_attach_series() from public,anon,authenticated;
create trigger ns_meeting_attach_series before insert on public.ns_internal_meetings for each row execute function public.ns_meeting_attach_series();
create function public.ns_schedule_meeting_series(p_id uuid,p_org uuid,p_site uuid,p_post uuid,p_title text,p_at timestamptz,p_members uuid[],p_agenda text,p_duration integer,p_frequency text,p_count integer) returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor uuid:=public.ns_current_member_id(p_org); target uuid; n integer; s public.ns_meeting_series%rowtype; payload jsonb; ids uuid[]:='{}'; mid uuid; prior text;
begin
 if actor is null or not public.ns_roster_enabled(p_org) or p_id is null or p_frequency is null or p_frequency not in ('daily','weekly') or p_count is null or p_count not between 2 and 12 or p_at is null or p_at<now()-interval '5 minutes' or p_at>now()+interval '1 year' or p_title is null or length(trim(p_title)) not between 1 and 160 or p_agenda is null or length(p_agenda)>2000 or p_duration is null or p_duration not between 5 and 480 or coalesce(cardinality(p_members),0) not between 1 and 100 then raise exception 'NS_SERIES_INVALID';end if;
 foreach target in array p_members loop
  if target is null or not public.ns_roster_can_manage(p_org,p_site,p_post,target) then raise exception 'NS_SERIES_FORBIDDEN';end if;
 end loop;
 payload:=jsonb_build_object('org',p_org,'site',p_site,'post',p_post,'title',trim(p_title),'at',p_at,'members',(select array_agg(distinct x order by x) from unnest(p_members) x),'agenda',trim(p_agenda),'duration',p_duration,'frequency',p_frequency,'count',p_count);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id::text,0));
 select * into s from public.ns_meeting_series where id=p_id;
 if found then
  if s.host_member_id is distinct from actor or s.request_payload is distinct from payload then raise exception 'NS_SERIES_CONFLICT';end if;
  select array_agg(id order by series_occurrence) into ids from public.ns_internal_meetings where series_id=p_id;
  if coalesce(cardinality(ids),0)<>p_count then raise exception 'NS_SERIES_INCOMPLETE';end if;
  return jsonb_build_object('id',p_id,'meeting_ids',ids,'duplicate',true);
 end if;
 insert into public.ns_meeting_series(id,org_id,site_id,host_member_id,frequency,occurrence_count,request_payload) values(p_id,p_org,p_site,actor,p_frequency,p_count,payload);
 prior:=current_setting('ns.meeting_series_id',true);
 perform set_config('ns.meeting_series_id',p_id::text,true);
 for n in 1..p_count loop
  mid:=md5(p_id::text||':'||n)::uuid;
  perform public.ns_schedule_internal_meeting_details(mid,p_org,p_site,p_post,p_title,p_at+make_interval(hours=>24*(n-1)*case when p_frequency='weekly' then 7 else 1 end),p_members,p_agenda,p_duration);
  if not exists(select 1 from public.ns_internal_meetings where id=mid and series_id=p_id and series_occurrence=n) then raise exception 'NS_SERIES_LINK_FAILED';end if;
  ids:=array_append(ids,mid);
 end loop;
 perform set_config('ns.meeting_series_id',coalesce(prior,''),true);
 return jsonb_build_object('id',p_id,'meeting_ids',ids,'duplicate',false);
end $f$;
revoke all on function public.ns_schedule_meeting_series(uuid,uuid,uuid,uuid,text,timestamptz,uuid[],text,integer,text,integer) from public,anon,authenticated;
grant execute on function public.ns_schedule_meeting_series(uuid,uuid,uuid,uuid,text,timestamptz,uuid[],text,integer,text,integer) to authenticated;

-- Atomically cancel all still-scheduled occurrences; preserve opened/closed/cancelled history.
create function public.ns_cancel_meeting_series(p_id uuid,p_expected jsonb) returns jsonb language plpgsql security definer set search_path='' as $f$
declare s public.ns_meeting_series%rowtype; m public.ns_internal_meetings%rowtype; actual jsonb; n integer:=0;
begin
 select * into s from public.ns_meeting_series where id=p_id for update;
 if not found or s.host_member_id is distinct from public.ns_current_member_id(s.org_id) or not public.ns_roster_enabled(s.org_id) then raise exception 'NS_SERIES_FORBIDDEN';end if;
 -- Lock all occurrences before validating the caller's snapshot.
 perform 1 from public.ns_internal_meetings where series_id=p_id order by id for update;
 if exists(select 1 from public.ns_internal_meetings where series_id=p_id and not public.ns_meeting_can_host(id)) then raise exception 'NS_SERIES_FORBIDDEN';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'revision',revision) order by id),'[]'::jsonb) into actual from public.ns_internal_meetings where series_id=p_id and status='scheduled';
 if jsonb_typeof(p_expected) is distinct from 'array' or jsonb_array_length(p_expected)>12 then raise exception 'NS_SERIES_STATE_CONFLICT';end if;
 if actual is distinct from (select coalesce(jsonb_agg(x order by x->>'id'),'[]'::jsonb) from jsonb_array_elements(p_expected) x) then raise exception 'NS_SERIES_STATE_CONFLICT';end if;
 for m in select * from public.ns_internal_meetings where series_id=p_id and status='scheduled' order by id loop
  perform public.ns_transition_internal_meeting(m.id,m.revision,'cancelled');n:=n+1;
 end loop;
 return jsonb_build_object('id',p_id,'cancelled_count',n);
end $f$;
revoke all on function public.ns_cancel_meeting_series(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.ns_cancel_meeting_series(uuid,jsonb) to authenticated;

-- Scheduled-only invite edits, with revision checks and a private audit of added/removed participants.
create table public.ns_meeting_invitation_changes(
 meeting_id uuid not null references public.ns_internal_meetings(id),revision integer not null,actor_member_id uuid not null,
 added uuid[] not null,removed uuid[] not null,changed_at timestamptz not null default clock_timestamp(),primary key(meeting_id,revision));
alter table public.ns_meeting_invitation_changes enable row level security;
revoke all on public.ns_meeting_invitation_changes from public,anon,authenticated;
create function public.ns_revise_meeting_invitees(p_id uuid,p_revision integer,p_title text,p_at timestamptz,p_agenda text,p_duration integer,p_members uuid[]) returns jsonb language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype; target uuid; wanted uuid[]; added uuid[]; removed uuid[]; result jsonb; loc text; msg jsonb; nid uuid;
begin
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if not found or not public.ns_meeting_can_host(p_id) then raise exception 'NS_MEETING_FORBIDDEN';end if;
 if m.status<>'scheduled' or m.revision is distinct from p_revision then raise exception 'NS_MEETING_STATE_CONFLICT';end if;
 if coalesce(cardinality(p_members),0) not between 1 and 100 then raise exception 'NS_MEETING_INVALID';end if;
 foreach target in array p_members loop
  if target is null or target=m.host_member_id or not public.ns_roster_can_manage(m.org_id,m.site_id,m.workstation_id,target) then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID';end if;
 end loop;
 select array_agg(distinct x order by x) into wanted from unnest(p_members) x;
 select coalesce(array_agg(i.member_id order by i.member_id),'{}') into removed from public.ns_internal_meeting_invitees i where i.meeting_id=p_id and i.member_id<>m.host_member_id and not(i.member_id=any(wanted));
 select coalesce(array_agg(x order by x),'{}') into added from unnest(wanted) x where not exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=p_id and i.member_id=x);
 delete from public.ns_internal_meeting_invitees where meeting_id=p_id and member_id=any(removed);
 insert into public.ns_internal_meeting_invitees(meeting_id,org_id,member_id) select p_id,m.org_id,x from unnest(added) x;
 -- Existing revision/history trigger resets RSVP and notifies the newly selected invitees.
 result:=public.ns_revise_internal_meeting(p_id,p_revision,p_title,p_at,p_agenda,p_duration);
 insert into public.ns_meeting_invitation_changes(meeting_id,revision,actor_member_id,added,removed) values(p_id,p_revision+1,m.host_member_id,added,removed);
 foreach target in array removed loop
  select coalesce(preferred_locale,'fr') into loc from public.ns_members where id=target and org_id=m.org_id;
  msg:=case loc when 'en' then jsonb_build_object('title','Invitation withdrawn','body','Your invitation to an internal meeting was withdrawn.')
   when 'ff-CM' then jsonb_build_object('title','Noddaango momtaama','body','Noddaango maa dental momtaama.')
   else jsonb_build_object('title','Invitation retirée','body','Votre invitation à une réunion interne a été retirée.') end;
  -- No meeting title, time, link or participant list is disclosed to a removed member.
  insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted)
    values(m.org_id,m.site_id,target,'push','internal_meeting.invitation_withdrawn','meeting-withdrawn:'||p_id::text||':'||target::text||':'||(p_revision+1),msg) returning id into nid;
  insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
    values(m.org_id,m.site_id,target,nid,'internal_meeting.invitation_withdrawn',msg,'sent',now());
 end loop;
 return result||jsonb_build_object('added_count',cardinality(added),'removed_count',cardinality(removed));
end $f$;
revoke all on function public.ns_revise_meeting_invitees(uuid,integer,text,timestamptz,text,integer,uuid[]) from public,anon,authenticated;
grant execute on function public.ns_revise_meeting_invitees(uuid,integer,text,timestamptz,text,integer,uuid[]) to authenticated;

rollback;
