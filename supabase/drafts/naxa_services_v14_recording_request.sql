begin;
-- v14 candidate: recording authorization lifecycle only. No worker, media file or successful recording is simulated.
create table public.ns_meeting_recording_requests(
 id uuid primary key,meeting_id uuid not null references public.ns_internal_meetings(id),requested_by uuid not null,
 status text not null check(status in ('requested','cancelled','stop_requested','failed','recording','ready')),
 requested_at timestamptz not null default clock_timestamp(),stop_requested_at timestamptz,
 display_name text not null check(length(display_name) between 1 and 220),
 check(status not in ('cancelled','stop_requested') or stop_requested_at is not null));
create unique index ns_recording_active on public.ns_meeting_recording_requests(meeting_id) where status in ('requested','recording','stop_requested');
alter table public.ns_meeting_recording_requests enable row level security;
revoke all on public.ns_meeting_recording_requests from public,anon,authenticated;
grant select on public.ns_meeting_recording_requests to authenticated;
create policy ns_recording_status_read on public.ns_meeting_recording_requests for select to authenticated using(public.ns_meeting_can_read(meeting_id));
create function public.ns_meeting_recording_consent_ok(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m where m.id=p_id and m.status='open'
 and exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.member_id=m.host_member_id and i.recording_consent is true)
 and not exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.excluded_at is null and i.response<>'declined'
 and public.ns_meeting_scope_valid(m.org_id,m.site_id,m.workstation_id,i.member_id,false) and i.recording_consent is distinct from true))
$f$;
revoke all on function public.ns_meeting_recording_consent_ok(uuid) from public,anon,authenticated;
create function public.ns_request_meeting_recording(p_id uuid,p_request uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype; r public.ns_meeting_recording_requests%rowtype;
begin
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if not found or not public.ns_meeting_can_host(p_id) or p_request is null or p_action is null or p_action not in ('start','stop') then raise exception 'NS_RECORDING_FORBIDDEN';end if;
 if p_action='start' then
  if m.status<>'open' or not public.ns_meeting_recording_consent_ok(p_id) then raise exception 'NS_RECORDING_CONSENT_REQUIRED';end if;
  select * into r from public.ns_meeting_recording_requests where id=p_request and meeting_id=p_id;
  if not found then
   insert into public.ns_meeting_recording_requests(id,meeting_id,requested_by,status,display_name) values(p_request,p_id,m.host_member_id,'requested',m.title||' — '||to_char(m.scheduled_at at time zone 'Africa/Douala','YYYY-MM-DD HH24-MI')) returning * into r;
  end if;
 else
  select * into r from public.ns_meeting_recording_requests where id=p_request and meeting_id=p_id for update;
  if not found then raise exception 'NS_RECORDING_FORBIDDEN';end if;
  if r.status in ('requested','recording') then
   update public.ns_meeting_recording_requests set status=case when status='requested' then 'cancelled' else 'stop_requested' end,stop_requested_at=clock_timestamp() where id=r.id returning * into r;
  end if;
 end if;
 return jsonb_build_object('id',r.id,'status',r.status,'display_name',r.display_name);
end $f$;
revoke all on function public.ns_request_meeting_recording(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ns_request_meeting_recording(uuid,uuid,text) to authenticated;
create function public.ns_recording_cancel_on_consent() returns trigger language plpgsql security definer set search_path='' as $f$
begin
 if new.recording_consent is distinct from true and old.recording_consent is true then
  update public.ns_meeting_recording_requests set status=case when status='requested' then 'cancelled' else 'stop_requested' end,stop_requested_at=clock_timestamp()
  where meeting_id=new.meeting_id and status in ('requested','recording');
 end if;
 return new;
end $f$;
revoke all on function public.ns_recording_cancel_on_consent() from public,anon,authenticated;
create trigger ns_recording_consent_guard after update of recording_consent on public.ns_internal_meeting_invitees for each row execute function public.ns_recording_cancel_on_consent();
create function public.ns_recording_cancel_on_close() returns trigger language plpgsql security definer set search_path='' as $f$
begin
 if old.status='open' and new.status<>'open' then
  update public.ns_meeting_recording_requests set status=case when status='requested' then 'cancelled' else 'stop_requested' end,stop_requested_at=clock_timestamp()
  where meeting_id=new.id and status in ('requested','recording');
 end if;
 return new;
end $f$;
revoke all on function public.ns_recording_cancel_on_close() from public,anon,authenticated;
create trigger ns_recording_close_guard after update of status on public.ns_internal_meetings for each row execute function public.ns_recording_cancel_on_close();
-- No authenticated route may mark recording/ready. Future trusted egress worker must enforce
-- current consent, active room membership, recording notice, provider receipt and private Storage object.

rollback;
