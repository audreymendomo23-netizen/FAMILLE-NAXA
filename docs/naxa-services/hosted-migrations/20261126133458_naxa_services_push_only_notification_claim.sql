create or replace function public.ns_claim_notification_batch(p_limit integer default 25)
returns table (
  id uuid,
  org_id uuid,
  site_id uuid,
  recipient_member_id uuid,
  event_code text,
  idempotency_key text,
  payload_redacted jsonb,
  attempts integer,
  claim_token uuid
)
language sql
security definer
set search_path = ''
as $naxa$
  with due as (
    select n.id
    from public.ns_notification_outbox n
    where n.channel = 'push' and n.recipient_member_id is not null
      and ((n.status = 'pending' and n.scheduled_at <= now())
       or (n.status = 'processing' and (n.claim_expires_at is null or n.claim_expires_at <= now())))
    order by n.scheduled_at, n.created_at
    for update skip locked
    limit least(greatest(coalesce(p_limit, 25), 1), 100)
  ), claimed as (
    update public.ns_notification_outbox n
    set status = 'processing',
        attempts = n.attempts + 1,
        claim_token = gen_random_uuid(),
        claim_expires_at = now() + interval '5 minutes',
        last_error_code = null
    from due
    where n.id = due.id
    returning n.id, n.org_id, n.site_id, n.recipient_member_id,
      n.event_code, n.idempotency_key, n.payload_redacted, n.attempts, n.claim_token
  )
  select * from claimed;
$naxa$;
