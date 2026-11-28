-- Administrative activation only, NOT a migration or a CI fixture.
-- Apply only on FAMILLE-NAXA after consented device and matched Vault/Edge secret verified.
-- Never supply or print the secret through SQL text or Git. Configure via the Vault dashboard.
begin;
do $guard$
begin
 if not exists(select 1 from vault.decrypted_secrets where name='GRILLAD_PUSH_JOB_SECRET' and length(decrypted_secret)>=32) then
   raise exception 'GRILLAD_PUSH_VAULT_NOT_READY';
 end if;
 if not exists(select 1 from grillad_private.push_devices where enabled and enrolled_at is not null and project_id='grillad') then
   raise exception 'GRILLAD_PUSH_DEVICE_NOT_READY';
 end if;
 if exists(select 1 from cron.job where jobname='grillad-push-dispatch-v1') then
   raise exception 'GRILLAD_PUSH_JOB_ALREADY_EXISTS';
 end if;
end $guard$;
select cron.schedule('grillad-push-dispatch-v1','*/2 * * * *',$job$
 select net.http_post(
  url:='https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/grillad-push',
  headers:=jsonb_build_object('Content-Type','application/json','x-grillad-job-secret',s.decrypted_secret),
  body:='{}'::jsonb,
  timeout_milliseconds:=120000
 ) from vault.decrypted_secrets s
 where s.name='GRILLAD_PUSH_JOB_SECRET' and length(s.decrypted_secret)>=32
 and exists(select 1 from grillad_private.push_devices where enabled and enrolled_at is not null and project_id='grillad')
$job$);
commit;
