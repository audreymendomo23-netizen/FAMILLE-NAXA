-- B6 candidate: isolated only. Existing 90-day test ceiling, not commercial policy.
begin;
alter table public.wm_recording_runs add column purge_requested_at timestamptz, add column purged_at timestamptz;
alter table public.wm_recording_runs add constraint wm_purge_state check(purged_at is null or (purge_requested_at is not null and phase='discarded' and storage_key is null and stored_at is null));
-- Lock first, fence reads and worker completion, and retain object key until verified deletion.
create function public.wm_b6_audio_purge_claim()
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare v public.wm_recording_runs%rowtype;
begin
 select * into v from public.wm_recording_runs
 where purged_at is null and ((phase='complete' and finished_at<=clock_timestamp()-interval '90 days') or (phase='discarded' and purge_requested_at is not null))
 order by purge_requested_at nulls last,finished_at,id for update skip locked limit 1;
 if not found then return null;end if;
 update public.wm_recording_runs set phase='discarded',disposition='discard',purge_requested_at=coalesce(purge_requested_at,clock_timestamp()) where id=v.id;
 delete from public.wm_transcription_jobs where recording_id=v.id;
 return jsonb_build_object('id',v.id,'room_id',v.room_id,'storage_key',v.storage_key,'object_name',v.object_name);
end $wm$;
create function public.wm_b6_audio_purge_ack(p_id uuid,p_key text)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
begin
 update public.wm_recording_runs set purged_at=clock_timestamp(),storage_key=null,stored_at=null,content_sha256=null,bytes=null
 where id=p_id and phase='discarded' and purge_requested_at is not null and purged_at is null and storage_key is not distinct from p_key;
 return found or exists(select 1 from public.wm_recording_runs where id=p_id and purged_at is not null);
end $wm$;
revoke all on function public.wm_b6_audio_purge_claim(),public.wm_b6_audio_purge_ack(uuid,text) from public,anon,authenticated;
grant execute on function public.wm_b6_audio_purge_claim(),public.wm_b6_audio_purge_ack(uuid,text) to service_role;
commit;
