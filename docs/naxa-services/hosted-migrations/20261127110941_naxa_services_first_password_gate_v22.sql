set local lock_timeout='3s';
do $guard$ begin if (select count(*) from public.ns_accounts)<>0 then raise exception 'NS_V22_BASELINE_CHANGED';end if;end $guard$;
-- First-login restriction is enforced by the shared RLS identity, not merely UI.
create or replace function public.ns_current_account_id()
returns uuid language sql stable security definer set search_path = ''
as $naxa$
 select a.id from public.ns_accounts a
 join public.ns_devices d on d.account_id=a.id
 where a.auth_user_id=auth.uid() and a.status='active'
 and a.password_change_required is false
 and d.session_id=auth.jwt()->>'session_id' and d.revoked_at is null
 limit 1;
$naxa$;
revoke all on function public.ns_current_account_id() from public,anon;
grant execute on function public.ns_current_account_id() to authenticated,service_role;

notify pgrst, 'reload schema';
