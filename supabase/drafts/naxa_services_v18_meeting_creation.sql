begin;
create function public.ns_schedule_internal_meeting_details(p_id uuid,p_org uuid,p_site uuid,p_post uuid,p_title text,p_at timestamptz,p_members uuid[],p_agenda text,p_duration integer) returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor uuid:=public.ns_current_member_id(p_org); target uuid; nid uuid; msg jsonb; loc text; existing public.ns_internal_meetings%rowtype;
begin
 if p_agenda is null or length(p_agenda)>2000 or p_duration is null or p_duration not between 5 and 480 or not public.ns_roster_enabled(p_org) or p_id is null or p_at is null or p_at<now()-interval '5 minutes' or p_title is null or length(trim(p_title)) not between 1 and 160 or coalesce(cardinality(p_members),0) not between 1 and 100 then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID'; end if;
 foreach target in array p_members loop
  if target is null or not public.ns_roster_can_manage(p_org,p_site,p_post,target) then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID'; end if;
 end loop;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id::text,0));
 select * into existing from public.ns_internal_meetings where id=p_id;
 if found then
  if existing.host_member_id is distinct from actor or not public.ns_meeting_can_host(p_id) or (existing.org_id,existing.site_id,existing.workstation_id,existing.title,existing.scheduled_at,existing.agenda,existing.duration_minutes) is distinct from (p_org,p_site,p_post,trim(p_title),p_at,trim(p_agenda),p_duration) or existing.status<>'scheduled' or existing.revision<>1 or (select array_agg(distinct i.member_id order by i.member_id) from public.ns_internal_meeting_invitees i where i.meeting_id=p_id and i.member_id<>actor) is distinct from (select array_agg(distinct x order by x) from unnest(p_members) x) then raise exception 'NS_MEETING_CREATE_CONFLICT';end if;
  return jsonb_build_object('id',p_id,'status','scheduled','revision',1,'duplicate',true);
 end if;
 insert into public.ns_internal_meetings(id,org_id,site_id,workstation_id,host_member_id,title,scheduled_at,status,agenda,duration_minutes) values(p_id,p_org,p_site,p_post,actor,trim(p_title),p_at,'scheduled',trim(p_agenda),p_duration);
 insert into public.ns_internal_meeting_invitees(meeting_id,org_id,member_id) values(p_id,p_org,actor);
 foreach target in array p_members loop
  insert into public.ns_internal_meeting_invitees(meeting_id,org_id,member_id) values(p_id,p_org,target) on conflict do nothing;
  if found then
   select coalesce(preferred_locale,'fr') into loc from public.ns_members where id=target;
   msg:=case loc when 'en' then jsonb_build_object('title','Meeting invitation','body','Open your internal meetings to review the invitation.')
    when 'ff-CM' then jsonb_build_object('title','Noddaango dental','body','Uddit dental golle ngam ƴeewtaade noddaango.')
    else jsonb_build_object('title','Invitation à une réunion','body','Consultez vos réunions internes pour voir votre invitation.') end;
   msg:=msg||jsonb_build_object('meeting_id',p_id,'route','/team');
   insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted)
    values(p_org,p_site,target,'push','internal_meeting.invited','meeting:'||p_id::text||':'||target::text,msg) returning id into nid;
   insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
    values(p_org,p_site,target,nid,'internal_meeting.invited',msg,'sent',now());
  end if;
 end loop;
 return jsonb_build_object('id',p_id,'status','scheduled','revision',1);
end $f$;

revoke all on function public.ns_schedule_internal_meeting_details(uuid,uuid,uuid,uuid,text,timestamptz,uuid[],text,integer) from public,anon,authenticated;
grant execute on function public.ns_schedule_internal_meeting_details(uuid,uuid,uuid,uuid,text,timestamptz,uuid[],text,integer) to authenticated;

rollback;
