-- CANDIDATE ONLY. Do not execute on hosted database without authorization and verified v30/v32 installation.
-- pg_cron must already be available; each commission event runs in its own transaction.
begin;
select cron.schedule('naxa-services-commission-events','10 seconds','select public.ns_process_next_commission_event();');
select cron.schedule('naxa-services-briefing-reminders','*/5 * * * *','select public.ns_emit_due_briefing_reminders();');
-- Default rollback preserves the review-only contract. Explicit approved activation requires separate execution.
rollback;
