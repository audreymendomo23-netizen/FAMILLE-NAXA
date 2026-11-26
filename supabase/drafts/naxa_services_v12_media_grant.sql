begin;
-- Candidate only: authorization for a single opaque SFU room, never provider admin credentials.
create function public.ns_meeting_media_grant(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype; actor uuid; host boolean;
begin
 if not public.ns_meeting_can_read(p_id) then raise exception 'NS_MEDIA_FORBIDDEN'; end if;
 select * into m from public.ns_internal_meetings where id=p_id;
 if m.status<>'open' then raise exception 'NS_MEDIA_NOT_OPEN'; end if;
 actor:=public.ns_current_member_id(m.org_id);host:=public.ns_meeting_can_host(p_id);
 if not host and not exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=p_id and i.member_id=actor and i.response<>'declined') then raise exception 'NS_MEDIA_FORBIDDEN'; end if;
 return jsonb_build_object('meeting_id',m.id,'member_id',actor,'room','ns-'||m.id::text,'host',host,'revision',m.revision);
end $f$;
revoke all on function public.ns_meeting_media_grant(uuid) from public,anon,authenticated;
grant execute on function public.ns_meeting_media_grant(uuid) to authenticated;

rollback;
