-- Dedicated private profile-photo paths: <organization UUID>/<member UUID>/avatar.{jpg,png,webp}
create or replace function public.ns_can_access_profile_photo(p_name text)
returns boolean language sql stable security definer set search_path='' as $fn$
 select exists(
  select 1 from public.ns_accounts a
  join public.ns_devices d on d.account_id=a.id
  join auth.sessions s on s.id::text=d.session_id and s.user_id=a.auth_user_id
  join public.ns_members m on m.account_id=a.id
  join public.ns_organizations o on o.id=m.org_id
  where a.auth_user_id=auth.uid() and a.status='active'
   and d.session_id=auth.jwt()->>'session_id' and d.revoked_at is null
   and (s.not_after is null or s.not_after>now()) and m.status='active' and o.status='active'
   and p_name in (m.org_id::text||'/'||m.id::text||'/avatar.jpg',m.org_id::text||'/'||m.id::text||'/avatar.png',m.org_id::text||'/'||m.id::text||'/avatar.webp')
 );
$fn$;
revoke all on function public.ns_can_access_profile_photo(text) from public,anon,authenticated;
grant execute on function public.ns_can_access_profile_photo(text) to authenticated,service_role;
create policy ns_profile_photo_read on storage.objects for select to authenticated using(bucket_id='ns-profile-photos' and public.ns_can_access_profile_photo(name));
create policy ns_profile_photo_insert on storage.objects for insert to authenticated with check(bucket_id='ns-profile-photos' and public.ns_can_access_profile_photo(name));
create policy ns_profile_photo_update on storage.objects for update to authenticated using(bucket_id='ns-profile-photos' and public.ns_can_access_profile_photo(name)) with check(bucket_id='ns-profile-photos' and public.ns_can_access_profile_photo(name));
create policy ns_profile_photo_delete on storage.objects for delete to authenticated using(bucket_id='ns-profile-photos' and public.ns_can_access_profile_photo(name));
-- A restrictive guard prevents a later broad authenticated policy from opening this bucket.
create policy ns_profile_photo_scope_guard on storage.objects as restrictive for all to authenticated using(bucket_id<>'ns-profile-photos' or public.ns_can_access_profile_photo(name)) with check(bucket_id<>'ns-profile-photos' or public.ns_can_access_profile_photo(name));
create policy ns_profile_photo_anon_guard on storage.objects as restrictive for all to anon using(bucket_id<>'ns-profile-photos') with check(bucket_id<>'ns-profile-photos');
