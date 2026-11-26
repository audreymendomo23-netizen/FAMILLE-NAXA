begin;
-- v12 candidate: invitation lifecycle, scope revocation and auditable meeting changes.
alter table public.ns_internal_meetings add column agenda text not null default '' check(length(agenda)<=2000),add column duration_minutes integer not null default 30 check(duration_minutes between 5 and 480);
alter table public.ns_internal_meeting_invitees add column response text not null default 'pending' check(response in ('pending','accepted','declined','tentative')),add column response_revision integer,add column responded_at timestamptz;
create table public.ns_internal_meeting_history(
 meeting_id uuid not null references public.ns_internal_meetings(id), revision integer not null, actor_member_id uuid not null,
 title text not null,scheduled_at timestamptz not null,agenda text not null,duration_minutes integer not null,status text not null,changed_at timestamptz not null default clock_timestamp(),primary key(meeting_id,revision));
alter table public.ns_internal_meeting_history enable row level security;
revoke all on public.ns_internal_meeting_history from public,anon,authenticated;
grant select on public.ns_internal_meeting_history to authenticated;
create policy ns_meeting_history_read on public.ns_internal_meeting_history for select to authenticated using(public.ns_meeting_can_read(meeting_id));
create function public.ns_meeting_scope_valid(p_org uuid,p_site uuid,p_post uuid,p_member uuid,p_manage boolean) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_members m join public.ns_member_scopes s on s.org_id=m.org_id and s.member_id=m.id
 join public.ns_sites t on t.org_id=m.org_id and t.id=p_site and t.status='active'
 where m.org_id=p_org and m.id=p_member and m.status='active'
 and (p_post is null or exists(select 1 from public.ns_workstations w where w.id=p_post and w.org_id=p_org and w.site_id=p_site and w.status='active'))
 and (case when p_manage then s.can_manage and m.role_code in ('promoter','network_manager','site_manager','workstation_manager') else (s.can_read or s.can_operate or s.can_manage) end)
 and ((s.scope_type='organization' and (not p_manage or m.role_code='promoter'))
 or (s.scope_type='site' and s.site_id=p_site and (not p_manage or m.role_code in ('promoter','network_manager','site_manager')))
 or (s.scope_type='workstation' and p_post is not null and s.site_id=p_site and s.workstation_id=p_post and (not p_manage or m.role_code='workstation_manager'))))
$f$;
revoke all on function public.ns_meeting_scope_valid(uuid,uuid,uuid,uuid,boolean) from public,anon,authenticated;
create or replace function public.ns_meeting_can_host(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m where m.id=p_id and public.ns_roster_enabled(m.org_id) and public.ns_erp_access_reason(m.org_id)<>'blocked'
 and m.host_member_id=public.ns_current_member_id(m.org_id) and public.ns_meeting_scope_valid(m.org_id,m.site_id,m.workstation_id,m.host_member_id,true))
$f$;
create or replace function public.ns_meeting_can_read(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m where m.id=p_id and public.ns_roster_enabled(m.org_id) and public.ns_erp_access_reason(m.org_id)<>'blocked'
 and (public.ns_meeting_can_host(m.id) or (m.host_member_id<>public.ns_current_member_id(m.org_id)
 and public.ns_meeting_scope_valid(m.org_id,m.site_id,m.workstation_id,public.ns_current_member_id(m.org_id),false)
 and exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.member_id=public.ns_current_member_id(m.org_id)))))
$f$;
create function public.ns_meeting_history_trigger() returns trigger language plpgsql security definer set search_path='' as $f$
declare i record; n uuid; msg jsonb; loc text; code text;
begin
 insert into public.ns_internal_meeting_history(meeting_id,revision,actor_member_id,title,scheduled_at,agenda,duration_minutes,status)
 values(new.id,new.revision,new.host_member_id,new.title,new.scheduled_at,new.agenda,new.duration_minutes,new.status);
 if tg_op='UPDATE' then
  if new.status='scheduled' then
   update public.ns_internal_meeting_invitees set response='pending',response_revision=null,responded_at=null,recording_consent=null,consent_at=null where meeting_id=new.id;
  end if;
  code:=case new.status when 'scheduled' then 'internal_meeting.updated' when 'open' then 'internal_meeting.opened' when 'closed' then 'internal_meeting.closed' else 'internal_meeting.cancelled' end;
  for i in select member_id from public.ns_internal_meeting_invitees where meeting_id=new.id and member_id<>new.host_member_id loop
   if public.ns_meeting_scope_valid(new.org_id,new.site_id,new.workstation_id,i.member_id,false) then
    select coalesce(preferred_locale,'fr') into loc from public.ns_members where id=i.member_id;
    msg:=case loc when 'en' then jsonb_build_object('title','Meeting update','body','Open your internal meetings to see the latest change.')
      when 'ff-CM' then jsonb_build_object('title','Dental hesɗitinaama','body','Uddit dental ngam ƴeewtaade baylugol.')
      else jsonb_build_object('title','Réunion mise à jour','body','Consultez vos réunions pour voir le changement.') end;
    msg:=msg||jsonb_build_object('meeting_id',new.id,'revision',new.revision,'route','/team');
    insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted)
    values(new.org_id,new.site_id,i.member_id,'push',code,'meeting:'||new.id::text||':'||i.member_id::text||':'||new.revision,msg) returning id into n;
    insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
    values(new.org_id,new.site_id,i.member_id,n,code,msg,'sent',now());
   end if;
  end loop;
 end if;
 return new;
end $f$;
revoke all on function public.ns_meeting_history_trigger() from public,anon,authenticated;
create trigger ns_meeting_history after insert or update on public.ns_internal_meetings for each row execute function public.ns_meeting_history_trigger();
create function public.ns_revise_internal_meeting(p_id uuid,p_revision integer,p_title text,p_at timestamptz,p_agenda text,p_duration integer) returns jsonb language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype;
begin
 if not public.ns_meeting_can_host(p_id) then raise exception 'NS_MEETING_FORBIDDEN'; end if;
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if m.status<>'scheduled' or m.revision is distinct from p_revision then raise exception 'NS_MEETING_STATE_CONFLICT'; end if;
 if p_title is null or length(trim(p_title)) not between 1 and 160 or p_at is null or p_at<now()-interval '5 minutes' or p_agenda is null or length(p_agenda)>2000 or p_duration is null or p_duration not between 5 and 480 then raise exception 'NS_MEETING_INVALID'; end if;
 update public.ns_internal_meetings set title=trim(p_title),scheduled_at=p_at,agenda=trim(p_agenda),duration_minutes=p_duration,revision=revision+1 where id=p_id returning * into m;
 return jsonb_build_object('id',m.id,'revision',m.revision,'status',m.status);
end $f$;
create function public.ns_respond_meeting_invitation(p_id uuid,p_revision integer,p_response text) returns boolean language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype;
begin
 if not public.ns_meeting_can_read(p_id) or p_response is null or p_response not in ('accepted','declined','tentative') then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID'; end if;
 select * into m from public.ns_internal_meetings where id=p_id for share;
 if m.status<>'scheduled' or m.revision is distinct from p_revision then raise exception 'NS_MEETING_STATE_CONFLICT'; end if;
 update public.ns_internal_meeting_invitees set response=p_response,response_revision=p_revision,responded_at=now()
 where meeting_id=p_id and member_id=public.ns_current_member_id(m.org_id) and member_id<>m.host_member_id;
 if not found then raise exception 'NS_MEETING_FORBIDDEN'; end if;
 return true;
end $f$;
revoke all on function public.ns_revise_internal_meeting(uuid,integer,text,timestamptz,text,integer),public.ns_respond_meeting_invitation(uuid,integer,text) from public,anon,authenticated;
grant execute on function public.ns_revise_internal_meeting(uuid,integer,text,timestamptz,text,integer),public.ns_respond_meeting_invitation(uuid,integer,text) to authenticated;

rollback;
