begin;
alter table public.wm_push_scheduler_tickets drop constraint wm_push_scheduler_tickets_outcome_check;
alter table public.wm_push_scheduler_tickets add constraint wm_push_scheduler_tickets_outcome_check check(outcome in ('configuration_invalid','oauth_failed','oauth_verified','disabled','dispatch_failed','dispatch_attention','dispatch_completed','fcm_validated','fcm_permission_denied','fcm_validation_failed'));
commit;