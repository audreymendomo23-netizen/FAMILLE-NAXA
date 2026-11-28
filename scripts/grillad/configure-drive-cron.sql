-- Administrative activation only. Not a migration or test fixture.
-- Use only in the GRILLAD Famille project, after verified Edge callback and OAuth consent.
-- Create the secret in Vault and configure the same secret in the dedicated Edge function; never commit it.
begin;
do $guard$
begin
 if not exists(select 1 from vault.decrypted_secrets where name='GRILLAD_DRIVE_JOB_SECRET' and length(decrypted_secret)>=32) then raise exception 'GRILLAD_DRIVE_VAULT_NOT_READY';end if;
 if not exists(select 1 from grillad_private.drive_connections) then raise exception 'GRILLAD_DRIVE_CONSENT_NOT_READY';end if;
 if exists(select 1 from cron.job where jobname='grillad-drive-dispatch-v1') then raise exception 'GRILLAD_DRIVE_JOB_ALREADY_EXISTS';end if;
end $guard$;
select cron.schedule('grillad-drive-dispatch-v1','*/2 * * * *',$job$
 select net.http_post(
  url:='https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/grillad-drive',
  headers:=jsonb_build_object('Content-Type','application/json','x-grillad-job-secret',s.decrypted_secret),
  body:='{}'::jsonb,timeout_milliseconds:=120000
 ) from vault.decrypted_secrets s
 where s.name='GRILLAD_DRIVE_JOB_SECRET' and length(s.decrypted_secret)>=32
 and exists(select 1 from grillad_private.drive_connections)
$job$);
commit;
