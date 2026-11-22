-- Runtime RLS tests for disposable PostgreSQL CI only; uses synthetic fixtures.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users(id) VALUES
 ('10000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000002');
INSERT INTO public.ns_organizations(id,display_name,business_mode,status,default_locale) VALUES
 ('20000000-0000-4000-8000-000000000001','Fixture organisation A','multi_site_network','active','fr'),
 ('20000000-0000-4000-8000-000000000002','Fixture organisation B','solo','active','fr');
INSERT INTO public.ns_sites(id,org_id,code,name,status) VALUES
 ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','A1','Site A1','active'),
 ('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','A2','Site A2','active'),
 ('30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000002','B1','Site B1','active');
INSERT INTO public.ns_workstations(id,org_id,site_id,code,name,kind,status) VALUES
 ('40000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','A1-C1','Workstation A1-C1','hair_chair','active'),
 ('40000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','A1-C2','Workstation A1-C2','hair_chair','active');
INSERT INTO public.ns_accounts(id,auth_user_id,login_id,auth_alias,status,password_change_required)
VALUES
 ('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','CI-USER-A','ci-user-a@example.invalid','active',false),
 ('50000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','CI-PROMOTER-A','ci-promoter-a@example.invalid','active',false);
INSERT INTO public.ns_members(id,org_id,account_id,display_name,role_code,status)
VALUES
 ('60000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','Fixture Site Manager','site_manager','active'),
 ('60000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000002','Fixture Network Promoter','promoter','active');
INSERT INTO public.ns_member_scopes(id,org_id,member_id,scope_type,scope_id,site_id,workstation_id,can_read,can_operate,can_manage)
VALUES ('70000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','site','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001',NULL,true,true,true);
INSERT INTO public.ns_member_scopes(id,org_id,member_id,scope_type,scope_id,site_id,workstation_id,can_read,can_operate,can_manage)
VALUES ('70000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000002','organization','20000000-0000-4000-8000-000000000001',NULL,NULL,true,true,true);
INSERT INTO public.ns_devices(id,account_id,installation_id,platform,label,remember_device,session_id)
VALUES ('80000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','ci-installation-a','android','Disposable CI device',true,'ci-session-a');
INSERT INTO public.ns_devices(id,account_id,installation_id,platform,label,remember_device,session_id)
VALUES ('80000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000002','ci-installation-promoter','android','Disposable CI promoter device',true,'ci-session-promoter');
INSERT INTO public.ns_customers(id,org_id,site_id,display_name,phone_contact) VALUES
 ('90000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Customer A1','690000001'),
 ('90000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','Customer A2','690000002'),
 ('90000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000003','Customer B1','690000003');
INSERT INTO public.ns_customers(id,org_id,site_id,display_name,phone_contact)
VALUES ('90000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Referred customer A1','690000004');
INSERT INTO public.ns_sales(id,org_id,site_id,sale_number,subtotal_xaf,discount_xaf,total_xaf,status,created_by,customer_id)
VALUES ('a0000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','CI-SALE-001',1000,0,1000,'posted','60000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001');
INSERT INTO public.ns_sales(id,org_id,site_id,sale_number,subtotal_xaf,discount_xaf,total_xaf,status,created_by,customer_id)
VALUES ('a0000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','CI-SALE-002',1500,0,1500,'posted','60000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000004');

COMMIT;

INSERT INTO public.ns_customer_referral_campaigns(
  id,org_id,name,status,starts_at,ends_at,beneficiary_mode,reward_kind,reward_value,
  minimum_paid_sale_xaf,reward_expiry_days,terms_version,terms_text,created_by,approved_by,approved_at
) VALUES (
  'd1000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'CI customer referral',
  'active',now()-interval '1 day',now()+interval '30 days',
  'both','points',100,500,30,'ci-v1','Conditions CI : le filleul effectue un premier achat encaissé. L’avantage est consultable et valable pendant la durée publiée.',
  '60000000-0000-4000-8000-000000000001',
  '60000000-0000-4000-8000-000000000001',now()
);
INSERT INTO public.ns_customer_referral_codes(
  id,org_id,site_id,campaign_id,customer_id,code
) VALUES (
  'd2000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  'd1000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000001',
  'CREF-C1A02611F0'
);
INSERT INTO public.ns_promotion_campaigns(
  id,org_id,title,campaign_type,status,starts_at,created_by
) VALUES (
  'd3000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'CI wheel legal gate','wheel','draft',now()-interval '1 day',
  '60000000-0000-4000-8000-000000000001'
);

INSERT INTO public.ns_notification_outbox(
  id,org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted,scheduled_at,status,attempts
) VALUES (
  'e1000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  '60000000-0000-4000-8000-000000000001',
  'push','ci.notification.sent','ci-notification-001',
  '{"title":"CI notification","body":"Redacted delivery fixture"}'::jsonb,
  now()-interval '1 minute','pending',0
),(
  'e1000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  '60000000-0000-4000-8000-000000000001',
  'push','ci.notification.retry','ci-notification-002',
  '{"title":"CI retry","body":"Retry fixture"}'::jsonb,
  now()-interval '1 minute','pending',0
);
INSERT INTO public.ns_push_tokens(
  id,org_id,member_id,device_id,platform,token_ciphertext,token_iv,token_fingerprint,token_tail
) VALUES (
  'e2000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '60000000-0000-4000-8000-000000000001',
  '80000000-0000-4000-8000-000000000001',
  'android',repeat('A',64),repeat('B',16),repeat('c',64),'ABCD'
);

BEGIN;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',false);
SELECT set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","session_id":"ci-session-a"}',false);
SET ROLE authenticated;
DO $rls$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.ns_customers;
  IF v_count <> 2 THEN RAISE EXCEPTION 'RLS_SITE_ISOLATION_FAILED: expected 2 customers on assigned site, got %',v_count; END IF;
  IF EXISTS (SELECT 1 FROM public.ns_customers WHERE id IN ('90000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000003')) THEN RAISE EXCEPTION 'RLS_CROSS_SITE_OR_TENANT_READ_FAILED'; END IF;
  IF public.ns_current_account_id() <> '50000000-0000-4000-8000-000000000001'::uuid THEN RAISE EXCEPTION 'DEVICE_SESSION_BINDING_FAILED'; END IF;
  IF public.ns_can_manage_org('20000000-0000-4000-8000-000000000001'::uuid) THEN RAISE EXCEPTION 'SITE_MANAGER_ESCALATED_TO_ORGANIZATION_MANAGER'; END IF;
  IF has_table_privilege(current_user,'public.ns_payments','UPDATE') THEN RAISE EXCEPTION 'CLIENT_CAN_UPDATE_PAYMENT_STATUS'; END IF;
  IF has_table_privilege(current_user,'public.ns_referrals','SELECT') OR has_table_privilege(current_user,'public.ns_referrals','INSERT') OR has_table_privilege(current_user,'public.ns_referral_rewards','UPDATE') THEN RAISE EXCEPTION 'CLIENT_HAS_DIRECT_REFERRAL_TABLE_ACCESS'; END IF;
  IF has_table_privilege(current_user,'public.ns_sync_receipts','SELECT') OR has_table_privilege(current_user,'public.ns_sync_conflicts','INSERT') OR has_table_privilege(current_user,'public.ns_notification_outbox','SELECT') THEN RAISE EXCEPTION 'CLIENT_HAS_SERVER_ONLY_SYNC_OR_NOTIFICATION_ACCESS'; END IF;
  IF has_table_privilege(current_user,'public.ns_customer_referral_campaigns','SELECT')
     OR has_table_privilege(current_user,'public.ns_customer_referral_codes','INSERT')
     OR has_table_privilege(current_user,'public.ns_customer_referral_rewards','UPDATE')
     OR has_table_privilege(current_user,'public.ns_promotion_campaigns','SELECT')
     OR has_table_privilege(current_user,'public.ns_promotion_spins','INSERT') THEN
    RAISE EXCEPTION 'CLIENT_HAS_DIRECT_CUSTOMER_REFERRAL_OR_PROMOTION_ACCESS';
  END IF;
  IF has_function_privilege(current_user,'public.ns_spin_promotion_wheel(uuid,uuid,uuid)','EXECUTE')
     OR has_function_privilege(current_user,'public.ns_record_customer_referral_first_paid_sale(uuid,text)','EXECUTE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_CALL_SERVER_ONLY_REFERRAL_OR_PROMOTION_RPC';
  END IF;
  IF NOT has_table_privilege('service_role','public.ns_customer_referrals','SELECT')
     OR NOT has_table_privilege('service_role','public.ns_promotion_spins','INSERT')
     OR NOT has_function_privilege('service_role','public.ns_spin_promotion_wheel(uuid,uuid,uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'V5_SERVER_ONLY_GRANTS_MISSING';
  END IF;
  IF has_table_privilege(current_user,'public.ns_push_tokens','SELECT')
     OR has_table_privilege(current_user,'public.ns_push_tokens','INSERT')
     OR has_table_privilege(current_user,'public.ns_notification_inbox','SELECT')
     OR has_table_privilege(current_user,'public.ns_notification_inbox','UPDATE')
     OR has_function_privilege(current_user,'public.ns_claim_notification_batch(integer)','EXECUTE') THEN
    RAISE EXCEPTION 'CLIENT_HAS_DIRECT_REMOTE_NOTIFICATION_ACCESS';
  END IF;
  IF NOT has_table_privilege('service_role','public.ns_push_tokens','SELECT')
     OR NOT has_table_privilege('service_role','public.ns_notification_inbox','INSERT')
     OR NOT has_function_privilege('service_role','public.ns_claim_notification_batch(integer)','EXECUTE') THEN
    RAISE EXCEPTION 'V6_SERVER_ONLY_GRANTS_MISSING';
  END IF;
  IF NOT has_table_privilege('service_role','public.ns_referrals','SELECT') OR NOT has_table_privilege('service_role','public.ns_sync_receipts','SELECT') THEN RAISE EXCEPTION 'SERVER_ROLE_GRANTS_MISSING'; END IF;
END
$rls$;

-- Run only server RPC checks as the database owner; these functions are intentionally service_role-only.
RESET ROLE;
DO $customer_referral$
DECLARE
  v_apply jsonb;
  v_qualify jsonb;
  v_repeat jsonb;
  v_reward_id uuid;
  v_reward_count integer;
  v_issued boolean;
BEGIN
  v_apply := public.ns_apply_customer_referral_code(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    '90000000-0000-4000-8000-000000000004'::uuid,
    'CREF-C1A02611F0'
  );
  IF coalesce((v_apply->>'accepted')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'CUSTOMER_REFERRAL_CODE_NOT_ACCEPTED: %',v_apply;
  END IF;

  -- The referral must be attributed before the first paid sale.
  INSERT INTO public.ns_payments(id,org_id,site_id,sale_id,payment_method,amount_xaf,status,confirmation_source,confirmed_by,confirmed_at,idempotency_key)
  VALUES ('b0000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000002','mobile_money',1500,'confirmed','provider_webhook','60000000-0000-4000-8000-000000000001',now(),'c0000000-0000-4000-8000-000000000002');

  v_qualify := public.ns_record_customer_referral_first_paid_sale(
    'a0000000-0000-4000-8000-000000000002'::uuid,'ci-provider-event-customer-sale-002'
  );
  IF coalesce((v_qualify->>'qualified')::boolean,false) IS NOT TRUE
     OR coalesce((v_qualify->>'rewards_created')::integer,0) <> 2 THEN
    RAISE EXCEPTION 'CUSTOMER_REFERRAL_FIRST_PAID_SALE_NOT_QUALIFIED: %',v_qualify;
  END IF;

  v_repeat := public.ns_record_customer_referral_first_paid_sale(
    'a0000000-0000-4000-8000-000000000002'::uuid,'ci-provider-event-customer-sale-002'
  );
  IF coalesce((v_repeat->>'idempotent')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'CUSTOMER_REFERRAL_EVENT_NOT_IDEMPOTENT: %',v_repeat;
  END IF;

  SELECT count(*)::integer INTO v_reward_count FROM public.ns_customer_referral_rewards;
  IF v_reward_count <> 2 THEN RAISE EXCEPTION 'CUSTOMER_REFERRAL_DUPLICATE_REWARD: %',v_reward_count; END IF;

  SELECT id INTO v_reward_id FROM public.ns_customer_referral_rewards ORDER BY created_at LIMIT 1;
  v_issued := public.ns_mark_customer_referral_reward_issued(v_reward_id,'ci-loyalty-ledger-001');
  IF NOT v_issued THEN RAISE EXCEPTION 'CUSTOMER_REFERRAL_REWARD_ISSUE_FAILED'; END IF;
  IF NOT public.ns_mark_customer_referral_reward_issued(v_reward_id,'ci-loyalty-ledger-001') THEN
    RAISE EXCEPTION 'CUSTOMER_REFERRAL_REWARD_ISSUE_NOT_IDEMPOTENT';
  END IF;

  v_apply := public.ns_apply_customer_referral_code(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    '90000000-0000-4000-8000-000000000001'::uuid,
    'CREF-C1A02611F0'
  );
  IF coalesce((v_apply->>'accepted')::boolean,true) IS TRUE
     OR v_apply->>'reason' <> 'self_referral' THEN
    RAISE EXCEPTION 'CUSTOMER_SELF_REFERRAL_NOT_REJECTED: %',v_apply;
  END IF;
END
$customer_referral$;

DO $promotion_legal_gate$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    INSERT INTO public.ns_promotion_campaigns(
      id,org_id,title,campaign_type,status,starts_at,terms_version,created_by,approved_by,approved_at
    ) VALUES (
      'd3000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000001',
      'CI forbidden unapproved wheel','wheel','active',now()-interval '1 day','ci-v1',
      '60000000-0000-4000-8000-000000000001',
      '60000000-0000-4000-8000-000000000001',now()
    );
  EXCEPTION WHEN check_violation THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'UNAPPROVED_PROMOTION_CAMPAIGN_ACTIVATED'; END IF;

  BEGIN
    PERFORM public.ns_spin_promotion_wheel(
      'd3000000-0000-4000-8000-000000000001'::uuid,
      '90000000-0000-4000-8000-000000000001'::uuid,
      'd4000000-0000-4000-8000-000000000001'::uuid
    );
    RAISE EXCEPTION 'DRAFT_PROMOTION_CAMPAIGN_ALLOWED_A_SPIN';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'NAXA_PROMOTION_CAMPAIGN_NOT_ACTIVE_OR_NOT_LEGAL' THEN RAISE; END IF;
  END;
END
$promotion_legal_gate$;

DO $notification_claim$
DECLARE
  v_claim record;
  v_retry_claim record;
  v_finished boolean;
  v_status text;
BEGIN
  SELECT * INTO v_claim
  FROM public.ns_claim_notification_batch(1)
  WHERE id = 'e1000000-0000-4000-8000-000000000001';
  IF NOT FOUND OR v_claim.claim_token IS NULL THEN
    RAISE EXCEPTION 'NOTIFICATION_OUTBOX_CLAIM_FAILED';
  END IF;
  IF v_claim.attempts <> 1 THEN RAISE EXCEPTION 'NOTIFICATION_ATTEMPT_NOT_INCREMENTED'; END IF;

  v_finished := public.ns_finish_notification_send(
    v_claim.id,v_claim.claim_token,'projects/naxa-services/messages/ci-message-001'
  );
  IF NOT v_finished THEN RAISE EXCEPTION 'NOTIFICATION_FINALIZATION_FAILED'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.ns_notification_outbox
    WHERE id = v_claim.id AND status = 'sent' AND provider_reference = 'projects/naxa-services/messages/ci-message-001'
  ) THEN RAISE EXCEPTION 'NOTIFICATION_OUTBOX_NOT_MARKED_SENT'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.ns_notification_inbox
    WHERE notification_id = v_claim.id AND member_id = '60000000-0000-4000-8000-000000000001'
      AND status = 'sent' AND read_at IS NULL
  ) THEN RAISE EXCEPTION 'NOTIFICATION_INBOX_ENTRY_NOT_CREATED'; END IF;

  UPDATE public.ns_notification_inbox SET status = 'read', read_at = now()
  WHERE notification_id = v_claim.id AND member_id = '60000000-0000-4000-8000-000000000001';
  v_finished := public.ns_finish_notification_send(
    v_claim.id,v_claim.claim_token,'projects/naxa-services/messages/duplicate-001'
  );
  IF v_finished THEN RAISE EXCEPTION 'STALE_NOTIFICATION_CLAIM_WAS_ACCEPTED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.ns_notification_inbox
    WHERE notification_id = v_claim.id AND status = 'read' AND read_at IS NOT NULL
  ) THEN RAISE EXCEPTION 'NOTIFICATION_READ_STATE_WAS_OVERWRITTEN'; END IF;

  SELECT * INTO v_retry_claim
  FROM public.ns_claim_notification_batch(1)
  WHERE id = 'e1000000-0000-4000-8000-000000000002';
  IF NOT FOUND OR v_retry_claim.claim_token IS NULL THEN RAISE EXCEPTION 'NOTIFICATION_RETRY_CLAIM_FAILED'; END IF;
  v_status := public.ns_fail_notification_send(
    v_retry_claim.id,v_retry_claim.claim_token,'FCM_TEMPORARY_UNAVAILABLE',true
  );
  IF v_status <> 'pending' THEN RAISE EXCEPTION 'RETRYABLE_NOTIFICATION_NOT_REQUEUED: %',v_status; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.ns_notification_outbox
    WHERE id = v_retry_claim.id AND status = 'pending' AND claim_token IS NULL
      AND scheduled_at > now() AND attempts = 1
  ) THEN RAISE EXCEPTION 'NOTIFICATION_RETRY_BACKOFF_NOT_SET'; END IF;
END
$notification_claim$;

SET ROLE authenticated;
DO $insert_guard$
BEGIN
  BEGIN
    INSERT INTO public.ns_customers(id,org_id,site_id,display_name)
    VALUES ('91000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','Forbidden cross-site insert');
    RAISE EXCEPTION 'RLS_ALLOWED_CROSS_SITE_CUSTOMER_INSERT';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END
$insert_guard$;

DO $payment_guard$
BEGIN
  BEGIN
    INSERT INTO public.ns_payments(id,org_id,site_id,sale_id,payment_method,amount_xaf,status,confirmed_by,confirmed_at,idempotency_key)
    VALUES ('b0000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000001','mobile_money',1000,'confirmed','60000000-0000-4000-8000-000000000001',now(),'c0000000-0000-4000-8000-000000000001');
    RAISE EXCEPTION 'RLS_ALLOWED_CLIENT_PAYMENT_CONFIRMATION';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END
$payment_guard$;
RESET ROLE;

DO $inventory_sync$
DECLARE
  v_item jsonb;
  v_updated jsonb;
  v_replay jsonb;
  v_quantity numeric(14,3);
  v_count integer;
  v_rejected boolean := false;
BEGIN
  v_item := public.ns_save_inventory_item(
    '92000000-0000-4000-8000-000000000001'::uuid,
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    'CI-STOCK-001','Inventory sync test item','pièce',2.5,'237690000001'
  );
  IF v_item->>'inventory_item_id' <> '92000000-0000-4000-8000-000000000001' THEN
    RAISE EXCEPTION 'INVENTORY_ITEM_LOCAL_UUID_NOT_PRESERVED: %',v_item;
  END IF;
  PERFORM public.ns_record_inventory_movement(
    '93000000-0000-4000-8000-000000000001'::uuid,
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    '92000000-0000-4000-8000-000000000001'::uuid,
    'in',12.5,'Opening inventory balance from import'
  );
  v_replay := public.ns_record_inventory_movement(
    '93000000-0000-4000-8000-000000000001'::uuid,
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    '92000000-0000-4000-8000-000000000001'::uuid,
    'in',12.5,'Opening inventory balance from import'
  );
  IF coalesce((v_replay->>'idempotent_replay')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'INVENTORY_MOVEMENT_REPLAY_NOT_IDEMPOTENT: %',v_replay;
  END IF;
  SELECT quantity INTO v_quantity FROM public.ns_inventory_items
    WHERE id='92000000-0000-4000-8000-000000000001';
  SELECT count(*) INTO v_count FROM public.ns_inventory_movements
    WHERE id='93000000-0000-4000-8000-000000000001';
  IF v_quantity<>12.5 OR v_count<>1 THEN
    RAISE EXCEPTION 'INVENTORY_MOVEMENT_DUPLICATED_OR_WRONG_BALANCE: quantity %, rows %',v_quantity,v_count;
  END IF;
  v_updated := public.ns_save_inventory_item(
    '92000000-0000-4000-8000-000000000001'::uuid,
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    'CI-STOCK-001','Inventory sync test item updated','pièce',3.0,'237690000002'
  );
  SELECT quantity INTO v_quantity FROM public.ns_inventory_items
    WHERE id='92000000-0000-4000-8000-000000000001';
  IF v_quantity<>12.5 OR v_updated->>'name'<>'Inventory sync test item updated' THEN
    RAISE EXCEPTION 'INVENTORY_METADATA_UPDATE_OVERWROTE_QUANTITY';
  END IF;
  BEGIN
    PERFORM public.ns_record_inventory_movement(
      '93000000-0000-4000-8000-000000000001'::uuid,
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,
      '92000000-0000-4000-8000-000000000001'::uuid,
      'in',13.5,'Changed payload under same movement ID'
    );
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM='NAXA_INVENTORY_MOVEMENT_IDEMPOTENCY_CONFLICT' THEN v_rejected:=true; ELSE RAISE; END IF;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'INVENTORY_MOVEMENT_CHANGED_REPLAY_NOT_REJECTED'; END IF;
  v_rejected:=false;
  BEGIN
    PERFORM public.ns_record_inventory_movement(
      '93000000-0000-4000-8000-000000000002'::uuid,
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,
      '92000000-0000-4000-8000-000000000001'::uuid,
      'consumption',-99,'Impossible negative stock test'
    );
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM='NAXA_INVENTORY_STOCK_WOULD_BE_NEGATIVE' THEN v_rejected:=true; ELSE RAISE; END IF;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'NEGATIVE_STOCK_MOVEMENT_NOT_REJECTED'; END IF;
  v_rejected:=false;
  BEGIN
    PERFORM public.ns_save_inventory_item(
      '92000000-0000-4000-8000-000000000002'::uuid,
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000002'::uuid,
      'CI-STOCK-SITE-B','Forbidden site item','pièce',0,''
    );
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM='NAXA_INVENTORY_ITEM_SAVE_FORBIDDEN' THEN v_rejected:=true; ELSE RAISE; END IF;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'INVENTORY_ITEM_CROSS_SITE_WRITE_NOT_REJECTED'; END IF;
END
$inventory_sync$;


SET ROLE authenticated;
DO $atomic_sync$
DECLARE
  v_payload jsonb;
  v_first jsonb;
  v_replay jsonb;
  v_rejected boolean := false;
BEGIN
  v_payload := jsonb_build_object(
    'supplier_id','94000000-0000-4000-8000-000000000001',
    'org_id','20000000-0000-4000-8000-000000000001',
    'site_id','30000000-0000-4000-8000-000000000001',
    'name','Fournisseur atomique CI','phone','','whatsapp','',
    'email','','address','','payment_terms_days',0,'notes',''
  );
  v_first := public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '95000000-0000-4000-8000-000000000001'::uuid,
    1,'supplier','94000000-0000-4000-8000-000000000001',
    'supplier.saved',v_payload
  );
  IF v_first->>'status' <> 'applied' OR coalesce((v_first->>'idempotent')::boolean,true) THEN
    RAISE EXCEPTION 'ATOMIC_SYNC_FIRST_MUTATION_NOT_APPLIED: %',v_first;
  END IF;

  v_replay := public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '95000000-0000-4000-8000-000000000001'::uuid,
    1,'supplier','94000000-0000-4000-8000-000000000001',
    'supplier.saved',v_payload
  );
  IF v_replay->>'status' <> 'applied' OR coalesce((v_replay->>'idempotent')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'ATOMIC_SYNC_IDENTICAL_REPLAY_NOT_IDEMPOTENT: %',v_replay;
  END IF;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,
      null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      '95000000-0000-4000-8000-000000000001'::uuid,
      1,'supplier','94000000-0000-4000-8000-000000000001',
      'supplier.saved',v_payload || jsonb_build_object('name','Fournisseur divergent')
    );
    RAISE EXCEPTION 'ATOMIC_SYNC_DIVERGENT_REPLAY_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'NAXA_SYNC_EVENT_IDEMPOTENCY_CONFLICT' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000002'::uuid,
      null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      '95000000-0000-4000-8000-000000000002'::uuid,
      2,'supplier','94000000-0000-4000-8000-000000000002',
      'supplier.saved',
      v_payload || jsonb_build_object(
        'supplier_id','94000000-0000-4000-8000-000000000002',
        'site_id','30000000-0000-4000-8000-000000000002'
      )
    );
    RAISE EXCEPTION 'ATOMIC_SYNC_CROSS_SITE_WRITE_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'NAXA_SYNC_SCOPE_FORBIDDEN' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,
      null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      '95000000-0000-4000-8000-000000000003'::uuid,
      3,'supplier','94000000-0000-4000-8000-000000000003',
      'supplier.saved',
      v_payload || jsonb_build_object(
        'supplier_id','94000000-0000-4000-8000-000000000003','name','x'
      )
    );
    RAISE EXCEPTION 'ATOMIC_SYNC_INVALID_MUTATION_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'NAXA_SUPPLIER_SAVE_INVALID' THEN RAISE; END IF;
  END;
END
$atomic_sync$;
RESET ROLE;

DO $atomic_sync_receipt_assertions$
DECLARE v_receipts integer; v_suppliers integer;
BEGIN
  SELECT count(*) INTO v_receipts FROM public.ns_sync_receipts
   WHERE org_id='20000000-0000-4000-8000-000000000001'
     AND client_event_id='95000000-0000-4000-8000-000000000001';
  SELECT count(*) INTO v_suppliers FROM public.ns_suppliers
   WHERE id='94000000-0000-4000-8000-000000000001'
     AND org_id='20000000-0000-4000-8000-000000000001'
     AND site_id='30000000-0000-4000-8000-000000000001';
  IF v_receipts <> 1 OR v_suppliers <> 1 THEN
    RAISE EXCEPTION 'ATOMIC_SYNC_RECEIPT_OR_MUTATION_COUNT_INVALID: receipts %, suppliers %',v_receipts,v_suppliers;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.ns_sync_receipts
    WHERE client_event_id IN (
      '95000000-0000-4000-8000-000000000002',
      '95000000-0000-4000-8000-000000000003'
    )
  ) THEN
    RAISE EXCEPTION 'ATOMIC_SYNC_FAILED_MUTATION_LEFT_RECEIPT';
  END IF;
END
$atomic_sync_receipt_assertions$;


SET ROLE authenticated;
DO $service_crm_sync$
DECLARE
  v_result jsonb;
  v_service_id uuid := '96000000-0000-4000-8000-000000000001';
  v_customer_id uuid := '96000000-0000-4000-8000-000000000002';
  v_followup_id uuid := '96000000-0000-4000-8000-000000000003';
  v_support_id uuid := '96000000-0000-4000-8000-000000000004';
  v_event_id uuid;
  v_payload jsonb;
BEGIN
  v_event_id := '97000000-0000-4000-8000-000000000001';
  v_payload := jsonb_build_object(
    'service_id',v_service_id,'org_id','20000000-0000-4000-8000-000000000001',
    'site_id','30000000-0000-4000-8000-000000000001',
    'code','CI-SERVICE-001','activity','pressing','name','Service CI',
    'duration_minutes',30,'price_xaf',1500,'active',true,'category','pressing',
    'description','Service de test transactionnel','provider_member_ids','[]'::jsonb,
    'required_workstation_kinds','[]'::jsonb,'package_sessions',null
  );
  v_result := public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_event_id,10,
    'service',v_service_id::text,'service.created',v_payload
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'SERVICE_CREATE_NOT_APPLIED: %',v_result; END IF;

  v_event_id := '97000000-0000-4000-8000-000000000002';
  v_payload := jsonb_build_object(
    'service_id',v_service_id,'org_id','20000000-0000-4000-8000-000000000001',
    'site_id','30000000-0000-4000-8000-000000000001',
    'code','CI-SERVICE-001','activity','pressing','name','Service CI updated',
    'duration_minutes',45,'price_xaf',1800,'active',true,'expected_version',1
  );
  v_result := public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_event_id,11,
    'service',v_service_id::text,'service.updated',v_payload
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'SERVICE_UPDATE_NOT_APPLIED: %',v_result; END IF;

  v_event_id := '97000000-0000-4000-8000-000000000003';
  v_payload := jsonb_build_object(
    'service_id',v_service_id,'org_id','20000000-0000-4000-8000-000000000001',
    'site_id','30000000-0000-4000-8000-000000000001',
    'category','pressing','description','Configuration mise à jour',
    'provider_member_ids','[]'::jsonb,'required_workstation_kinds','[]'::jsonb,
    'package_sessions',2,'expected_version',2
  );
  v_result := public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_event_id,12,
    'service',v_service_id::text,'service.configuration_updated',v_payload
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'SERVICE_CONFIGURATION_NOT_APPLIED: %',v_result; END IF;

  v_event_id := '97000000-0000-4000-8000-000000000004';
  v_payload := jsonb_build_object(
    'customer_id',v_customer_id,'org_id','20000000-0000-4000-8000-000000000001',
    'site_id','30000000-0000-4000-8000-000000000001',
    'display_name','Client CRM CI','phone_contact','690000009',
    'contact_consent',false,'address_line','Rue de test','neighborhood','Akwa',
    'landmark','près du marché','notes_private',''
  );
  v_result := public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_event_id,13,
    'customer',v_customer_id::text,'customer.created',v_payload
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'CUSTOMER_CREATE_NOT_APPLIED: %',v_result; END IF;

  v_event_id := '97000000-0000-4000-8000-000000000005';
  v_payload := jsonb_build_object(
    'followup_id',v_followup_id,'org_id','20000000-0000-4000-8000-000000000001',
    'site_id','30000000-0000-4000-8000-000000000001','customer_id',v_customer_id,
    'title','Rappeler le client','frequency','weekly','channel','whatsapp',
    'notes','Relance CRM CI','next_due_at',now()+interval '7 days','status','active'
  );
  v_result := public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_event_id,14,
    'customer_followup',v_followup_id::text,'customer_followup.created',v_payload
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'CUSTOMER_FOLLOWUP_CREATE_NOT_APPLIED: %',v_result; END IF;

  v_event_id := '97000000-0000-4000-8000-000000000006';
  v_payload := jsonb_build_object(
    'followup_id',v_followup_id,'org_id','20000000-0000-4000-8000-000000000001',
    'site_id','30000000-0000-4000-8000-000000000001',
    'completed_at',now(),'next_due_at_if_repeating',now()+interval '14 days',
    'completion_note','Client contacté en recette'
  );
  v_result := public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_event_id,15,
    'customer_followup',v_followup_id::text,'customer_followup.completed',v_payload
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'CUSTOMER_FOLLOWUP_COMPLETION_NOT_APPLIED: %',v_result; END IF;

  v_event_id := '97000000-0000-4000-8000-000000000007';
  v_payload := jsonb_build_object(
    'request_id',v_support_id,'org_id','20000000-0000-4000-8000-000000000001',
    'site_id','30000000-0000-4000-8000-000000000001',
    'subject','Demande support CI','description','Vérification du parcours de support serveur.',
    'priority','normal'
  );
  v_result := public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_event_id,16,
    'support_request',v_support_id::text,'support_request.created',v_payload
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'SUPPORT_REQUEST_CREATE_NOT_APPLIED: %',v_result; END IF;
END
$service_crm_sync$;
RESET ROLE;

DO $service_crm_assertions$
DECLARE v_revision integer; v_followup_status text; v_followup_events integer; v_support_status text;
BEGIN
  SELECT revision INTO v_revision FROM public.ns_services
   WHERE id='96000000-0000-4000-8000-000000000001';
  IF v_revision<>3 THEN RAISE EXCEPTION 'SERVICE_VERSION_SEQUENCE_INVALID: %',v_revision; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.ns_customers
    WHERE id='96000000-0000-4000-8000-000000000002'
      AND address_line='Rue de test' AND contact_consent=false
  ) THEN RAISE EXCEPTION 'CUSTOMER_CONSENT_OR_ADDRESS_NOT_PERSISTED'; END IF;
  SELECT status INTO v_followup_status FROM public.ns_customer_followups
   WHERE id='96000000-0000-4000-8000-000000000003';
  SELECT count(*) INTO v_followup_events FROM public.ns_customer_followup_events
   WHERE followup_id='96000000-0000-4000-8000-000000000003';
  IF v_followup_status<>'active' OR v_followup_events<>1 THEN
    RAISE EXCEPTION 'FOLLOWUP_COMPLETION_LEDGER_INVALID: %, %',v_followup_status,v_followup_events;
  END IF;
  SELECT status INTO v_support_status FROM public.ns_support_requests
   WHERE id='96000000-0000-4000-8000-000000000004';
  IF v_support_status<>'open' THEN RAISE EXCEPTION 'SUPPORT_REQUEST_NOT_OPEN: %',v_support_status; END IF;
END
$service_crm_assertions$;


SET ROLE authenticated;
DO $inventory_valuation_sync$
DECLARE v_result jsonb; v_rejected boolean:=false; v_version integer;
BEGIN
  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '99000000-0000-4000-8000-000000000001'::uuid,20,
    'inventory_valuation','92000000-0000-4000-8000-000000000001',
    'inventory_valuation.imported',
    jsonb_build_object(
      'valuation_id','98000000-0000-4000-8000-000000000001',
      'inventory_item_id','92000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'unit_cost_xaf',1500,'selling_price_xaf',3000,'expected_version',0
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'VALUATION_IMPORT_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '99000000-0000-4000-8000-000000000002'::uuid,21,
    'inventory_valuation','92000000-0000-4000-8000-000000000001',
    'inventory_valuation.import_updated',
    jsonb_build_object(
      'valuation_id','98000000-0000-4000-8000-000000000001',
      'inventory_item_id','92000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'unit_cost_xaf',1600,'selling_price_xaf',3200,'expected_version',1
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'VALUATION_IMPORT_UPDATE_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '99000000-0000-4000-8000-000000000003'::uuid,22,
    'inventory_valuation','92000000-0000-4000-8000-000000000001',
    'inventory_valuation.updated',
    jsonb_build_object(
      'valuation_id','98000000-0000-4000-8000-000000000001',
      'inventory_item_id','92000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'unit_cost_xaf',1700,'selling_price_xaf',3500,'expected_version',2
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'VALUATION_UPDATE_NOT_APPLIED: %',v_result; END IF;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      '99000000-0000-4000-8000-000000000004'::uuid,23,
      'inventory_valuation','92000000-0000-4000-8000-000000000001',
      'inventory_valuation.updated',
      jsonb_build_object(
        'valuation_id','98000000-0000-4000-8000-000000000001',
        'inventory_item_id','92000000-0000-4000-8000-000000000001',
        'org_id','20000000-0000-4000-8000-000000000001',
        'site_id','30000000-0000-4000-8000-000000000001',
        'unit_cost_xaf',1750,'selling_price_xaf',3600,'expected_version',1
      )
    );
    RAISE EXCEPTION 'STALE_INVENTORY_VALUATION_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'NAXA_INVENTORY_VALUATION_VERSION_CONFLICT' THEN RAISE; END IF;
  END;
END
$inventory_valuation_sync$;
RESET ROLE;

DO $inventory_valuation_assertions$
DECLARE v_cost bigint; v_price bigint; v_revision integer; v_item_cost bigint; v_item_price bigint;
BEGIN
  SELECT unit_cost_xaf,selling_price_xaf,revision INTO v_cost,v_price,v_revision
  FROM public.ns_inventory_valuations
  WHERE id='98000000-0000-4000-8000-000000000001';
  SELECT average_unit_cost_xaf,selling_price_xaf INTO v_item_cost,v_item_price
  FROM public.ns_inventory_items WHERE id='92000000-0000-4000-8000-000000000001';
  IF v_cost<>1700 OR v_price<>3500 OR v_revision<>3 OR v_item_cost<>1700 OR v_item_price<>3500 THEN
    RAISE EXCEPTION 'INVENTORY_VALUATION_LEDGER_OR_PROJECTION_INVALID';
  END IF;
END
$inventory_valuation_assertions$;

SET ROLE authenticated;
DO $inventory_valuation_direct_write_guard$
BEGIN
  IF has_table_privilege(current_user,'public.ns_inventory_valuations','SELECT')
     OR has_table_privilege(current_user,'public.ns_inventory_valuations','INSERT')
     OR has_table_privilege(current_user,'public.ns_inventory_valuations','UPDATE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_INVENTORY_VALUATION_RPC';
  END IF;
END
$inventory_valuation_direct_write_guard$;
RESET ROLE;


SET ROLE authenticated;
DO $pressing_appointment_sync$
DECLARE
  v_result jsonb;
  v_start timestamptz:=now()+interval '4 hours';
  v_end timestamptz:=now()+interval '5 hours';
  v_rejected boolean:=false;
BEGIN
  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    '40000000-0000-4000-8000-000000000001'::uuid,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9a000000-0000-4000-8000-000000000001'::uuid,60,
    'pressing_order','9b000000-0000-4000-8000-000000000001',
    'pressing_order.created',
    jsonb_build_object(
      'order_id','9b000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'workstation_id','40000000-0000-4000-8000-000000000001',
      'ticket_number','CI-PRESS-001','customer_name','Client Pressing CI',
      'customer_phone','690000010','items_summary','2 chemises, 1 pantalon',
      'total_xaf',4500,'deposit_xaf',1500,'promised_at',now()+interval '2 days'
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'PRESSING_ORDER_CREATE_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9a000000-0000-4000-8000-000000000002'::uuid,61,
    'pressing_order','9b000000-0000-4000-8000-000000000001',
    'pressing_order.status_changed:in_progress',
    jsonb_build_object(
      'order_id','9b000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'from_status','received','reason','Début du traitement',
      'expected_version',1,'transitioned_at',now()
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'PRESSING_TO_PROGRESS_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9a000000-0000-4000-8000-000000000003'::uuid,62,
    'pressing_order','9b000000-0000-4000-8000-000000000001',
    'pressing_order.status_changed:ready',
    jsonb_build_object(
      'order_id','9b000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'from_status','in_progress','reason','Traitement terminé',
      'expected_version',2,'transitioned_at',now()
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'PRESSING_TO_READY_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9a000000-0000-4000-8000-000000000004'::uuid,63,
    'pressing_order','9b000000-0000-4000-8000-000000000001',
    'pressing_order.status_changed:picked_up',
    jsonb_build_object(
      'order_id','9b000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'from_status','ready','reason','Client servi',
      'expected_version',3,'transitioned_at',now()
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'PRESSING_TO_PICKED_UP_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,
    '40000000-0000-4000-8000-000000000001'::uuid,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9a000000-0000-4000-8000-000000000005'::uuid,64,
    'appointment','9c000000-0000-4000-8000-000000000001',
    'appointment.created',
    jsonb_build_object(
      'appointment_id','9c000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'workstation_id','40000000-0000-4000-8000-000000000001',
      'customer_reference_or_name','Client rendez-vous CI',
      'service_reference_or_name','Pressing standard',
      'assigned_member_id','60000000-0000-4000-8000-000000000001',
      'starts_at',v_start,'ends_at',v_end,'deposit_xaf',1000,'status','booked'
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'APPOINTMENT_CREATE_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9a000000-0000-4000-8000-000000000006'::uuid,65,
    'appointment','9c000000-0000-4000-8000-000000000001',
    'appointment.status_changed',
    jsonb_build_object(
      'appointment_id','9c000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'from_status','booked','to_status','confirmed',
      'reason','Confirmation du client','expected_version',1,'transitioned_at',now()
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'APPOINTMENT_STATUS_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9a000000-0000-4000-8000-000000000007'::uuid,66,
    'appointment','9c000000-0000-4000-8000-000000000001',
    'appointment.rescheduled',
    jsonb_build_object(
      'appointment_id','9c000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'workstation_id','40000000-0000-4000-8000-000000000001',
      'assigned_member_id','60000000-0000-4000-8000-000000000001',
      'starts_at',v_start+interval '2 hours','ends_at',v_end+interval '2 hours',
      'expected_version',2,'reason','Décalage horaire demandé'
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'APPOINTMENT_RESCHEDULE_NOT_APPLIED: %',v_result; END IF;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      '9a000000-0000-4000-8000-000000000008'::uuid,67,
      'appointment','9c000000-0000-4000-8000-000000000002',
      'appointment.created',
      jsonb_build_object(
        'appointment_id','9c000000-0000-4000-8000-000000000002',
        'org_id','20000000-0000-4000-8000-000000000001',
        'site_id','30000000-0000-4000-8000-000000000001',
        'workstation_id','40000000-0000-4000-8000-000000000001',
        'customer_reference_or_name','Second client',
        'service_reference_or_name','Pressing standard',
        'assigned_member_id','60000000-0000-4000-8000-000000000001',
        'starts_at',v_start+interval '2 hours','ends_at',v_end+interval '2 hours',
        'deposit_xaf',0,'status','booked'
      )
    );
    RAISE EXCEPTION 'APPOINTMENT_OVERLAPPING_CREATE_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'NAXA_APPOINTMENT_SLOT_CONFLICT' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      '9a000000-0000-4000-8000-000000000009'::uuid,68,
      'appointment','9c000000-0000-4000-8000-000000000001',
      'appointment.status_changed',
      jsonb_build_object(
        'appointment_id','9c000000-0000-4000-8000-000000000001',
        'org_id','20000000-0000-4000-8000-000000000001',
        'site_id','30000000-0000-4000-8000-000000000001',
        'from_status','confirmed','to_status','completed',
        'reason','Clôture de rendez-vous','expected_version',2,'transitioned_at',now()
      )
    );
    RAISE EXCEPTION 'STALE_APPOINTMENT_STATUS_UPDATE_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'NAXA_APPOINTMENT_VERSION_CONFLICT' THEN RAISE; END IF;
  END;
END
$pressing_appointment_sync$;
RESET ROLE;

DO $pressing_appointment_assertions$
DECLARE v_pressing_status text; v_pressing_revision integer; v_pressing_events integer;
        v_appointment_status text; v_appointment_revision integer; v_appointment_events integer;
BEGIN
  SELECT status,revision INTO v_pressing_status,v_pressing_revision
    FROM public.ns_pressing_orders WHERE id='9b000000-0000-4000-8000-000000000001';
  SELECT count(*) INTO v_pressing_events FROM public.ns_pressing_status_events
    WHERE order_id='9b000000-0000-4000-8000-000000000001';
  IF v_pressing_status<>'picked_up' OR v_pressing_revision<>4 OR v_pressing_events<>4 THEN
    RAISE EXCEPTION 'PRESSING_ORDER_LIFECYCLE_INVALID';
  END IF;
  SELECT status,revision INTO v_appointment_status,v_appointment_revision
    FROM public.ns_appointments WHERE id='9c000000-0000-4000-8000-000000000001';
  SELECT count(*) INTO v_appointment_events FROM public.ns_appointment_status_events
    WHERE appointment_id='9c000000-0000-4000-8000-000000000001';
  IF v_appointment_status<>'confirmed' OR v_appointment_revision<>3 OR v_appointment_events<>3 THEN
    RAISE EXCEPTION 'APPOINTMENT_LIFECYCLE_OR_REVISION_INVALID';
  END IF;
END
$pressing_appointment_assertions$;

SET ROLE authenticated;
DO $pressing_appointment_direct_write_guard$
BEGIN
  IF has_table_privilege(current_user,'public.ns_pressing_orders','INSERT')
     OR has_table_privilege(current_user,'public.ns_pressing_orders','UPDATE')
     OR has_table_privilege(current_user,'public.ns_appointments','INSERT')
     OR has_table_privilege(current_user,'public.ns_appointments','UPDATE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_PRESSING_OR_APPOINTMENT_RPC';
  END IF;
END
$pressing_appointment_direct_write_guard$;
RESET ROLE;


INSERT INTO public.ns_cash_registers(id,org_id,site_id,code,name,workstation_id,active)
VALUES (
  '9e000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  'CI-CAISSE-001','Caisse CI',
  '40000000-0000-4000-8000-000000000001',true
);

SET ROLE authenticated;
DO $cash_session_expense_sync$
DECLARE v_result jsonb; v_rejected boolean:=false;
BEGIN
  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9d000000-0000-4000-8000-000000000001'::uuid,70,
    'cash_session','9f000000-0000-4000-8000-000000000001',
    'cash_session.opened',
    jsonb_build_object(
      'cash_session_id','9f000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'register_id','9e000000-0000-4000-8000-000000000001',
      'register_name','Caisse CI','opening_float_xaf',5000,'opened_at',now()
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'CASH_SESSION_OPEN_NOT_APPLIED: %',v_result; END IF;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      '9d000000-0000-4000-8000-000000000002'::uuid,71,
      'cash_session','9f000000-0000-4000-8000-000000000002',
      'cash_session.opened',
      jsonb_build_object(
        'cash_session_id','9f000000-0000-4000-8000-000000000002',
        'org_id','20000000-0000-4000-8000-000000000001',
        'site_id','30000000-0000-4000-8000-000000000001',
        'register_id','9e000000-0000-4000-8000-000000000001',
        'register_name','Caisse CI','opening_float_xaf',1000,'opened_at',now()
      )
    );
    RAISE EXCEPTION 'SECOND_OPEN_CASH_SESSION_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'NAXA_CASH_SESSION_ALREADY_OPEN' THEN RAISE; END IF;
  END;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9d000000-0000-4000-8000-000000000003'::uuid,72,
    'expense','a1000000-0000-4000-8000-000000000001',
    'expense.created',
    jsonb_build_object(
      'expense_id','a1000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'cash_session_id','9f000000-0000-4000-8000-000000000001',
      'category','Fournitures','description','Achat de consommables',
      'amount_xaf',1000,'occurred_at',now()
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'CASH_EXPENSE_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9d000000-0000-4000-8000-000000000005'::uuid,73,
    'pressing_order','a8000000-0000-4000-8000-000000000001','pressing_order.created',
    jsonb_build_object(
      'order_id','a8000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'ticket_number','PRS-CI-CASH-001','customer_name','Client pressing espèces',
      'customer_phone','690000101','items_summary','Deux chemises',
      'total_xaf',6000,'deposit_xaf',1200,'deposit_payment_method','cash',
      'cash_session_id','9f000000-0000-4000-8000-000000000001',
      'promised_at',now()+interval '1 day'
    )
  );
  IF v_result->>'status'<>'applied'
     OR v_result->'result'->>'deposit_payment_status'<>'confirmed'
     OR v_result->'result'->>'deposit_payment_method'<>'cash'
     OR v_result->'result'->>'cash_session_id'<>'9f000000-0000-4000-8000-000000000001' THEN
    RAISE EXCEPTION 'PRESSING_CASH_DEPOSIT_NOT_CONFIRMED_AND_LINKED: %',v_result;
  END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9d000000-0000-4000-8000-000000000006'::uuid,74,
    'pressing_order','a8000000-0000-4000-8000-000000000002','pressing_order.created',
    jsonb_build_object(
      'order_id','a8000000-0000-4000-8000-000000000002',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'ticket_number','PRS-CI-MOMO-001','customer_name','Client pressing Mobile Money',
      'customer_phone','690000102','items_summary','Un costume',
      'total_xaf',9000,'deposit_xaf',800,'deposit_payment_method','mobile_money',
      'cash_session_id',null,'promised_at',now()+interval '1 day'
    )
  );
  IF v_result->>'status'<>'applied'
     OR v_result->'result'->>'deposit_payment_status'<>'pending'
     OR v_result->'result'->>'deposit_payment_method'<>'mobile_money'
     OR v_result->'result'->>'cash_session_id' is not null THEN
    RAISE EXCEPTION 'PRESSING_MOBILE_MONEY_DEPOSIT_MUST_REMAIN_PENDING: %',v_result;
  END IF;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      '9d000000-0000-4000-8000-000000000007'::uuid,75,
      'pressing_order','a8000000-0000-4000-8000-000000000003','pressing_order.created',
      jsonb_build_object(
        'order_id','a8000000-0000-4000-8000-000000000003',
        'org_id','20000000-0000-4000-8000-000000000001',
        'site_id','30000000-0000-4000-8000-000000000001',
        'ticket_number','PRS-CI-INVALID-001','customer_name','Client sans caisse',
        'customer_phone','690000103','items_summary','Un pantalon',
        'total_xaf',3000,'deposit_xaf',500,'deposit_payment_method','cash',
        'cash_session_id',null,'promised_at',now()+interval '1 day'
      )
    );
    RAISE EXCEPTION 'PRESSING_CASH_DEPOSIT_WITHOUT_SESSION_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'NAXA_PRESSING_DEPOSIT_CASH_SESSION_REQUIRED' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      '9d000000-0000-4000-8000-000000000008'::uuid,76,
      'cash_session','9f000000-0000-4000-8000-000000000001',
      'cash_session.closed',
      jsonb_build_object(
        'cash_session_id','9f000000-0000-4000-8000-000000000001',
        'org_id','20000000-0000-4000-8000-000000000001',
        'site_id','30000000-0000-4000-8000-000000000001',
        'counted_close_xaf',3900,'variance_reason','','closed_at',now()+interval '1 minute'
      )
    );
    RAISE EXCEPTION 'CASH_CLOSE_WITH_UNJUSTIFIED_VARIANCE_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'NAXA_CASH_VARIANCE_REASON_REQUIRED' THEN RAISE; END IF;
  END;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    '9d000000-0000-4000-8000-000000000004'::uuid,73,
    'cash_session','9f000000-0000-4000-8000-000000000001',
    'cash_session.closed',
    jsonb_build_object(
      'cash_session_id','9f000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'counted_close_xaf',5200,'variance_reason','','closed_at',now()+interval '1 minute'
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'CASH_SESSION_CLOSE_NOT_APPLIED: %',v_result; END IF;
  IF (v_result->>'expected_close_xaf')::bigint<>5200
     OR (v_result->>'pressing_deposits_cash_xaf')::bigint<>1200
     OR (v_result->>'variance_xaf')::bigint<>0 THEN
    RAISE EXCEPTION 'CASH_SESSION_BALANCE_NOT_COMPUTED_FROM_SERVER_LEDGER: %',v_result;
  END IF;
END
$cash_session_expense_sync$;
RESET ROLE;

DO $cash_session_assertions$
DECLARE
  v_status text; v_expected bigint; v_expenses bigint; v_receipts integer;
  v_pressing_cash_status text; v_pressing_momo_status text;
  v_pressing_cash_session uuid; v_pressing_momo_session uuid;
BEGIN
  SELECT status,expected_close_xaf INTO v_status,v_expected
    FROM public.ns_cash_sessions WHERE id='9f000000-0000-4000-8000-000000000001';
  SELECT sum(amount_xaf) INTO v_expenses FROM public.ns_expenses
    WHERE cash_session_id='9f000000-0000-4000-8000-000000000001';
  SELECT count(*) INTO v_receipts FROM public.ns_sync_receipts
    WHERE client_event_id='9d000000-0000-4000-8000-000000000008';
  SELECT status,cash_session_id INTO v_pressing_cash_status,v_pressing_cash_session
    FROM public.ns_payments WHERE pressing_order_id='a8000000-0000-4000-8000-000000000001';
  SELECT status,cash_session_id INTO v_pressing_momo_status,v_pressing_momo_session
    FROM public.ns_payments WHERE pressing_order_id='a8000000-0000-4000-8000-000000000002';
  IF v_status<>'closed' OR v_expected<>5200 OR v_expenses<>1000 OR v_receipts<>1
     OR v_pressing_cash_status<>'confirmed'
     OR v_pressing_cash_session<>'9f000000-0000-4000-8000-000000000001'
     OR v_pressing_momo_status<>'pending' OR v_pressing_momo_session is not null THEN
    RAISE EXCEPTION 'CASH_SESSION_SERVER_BALANCE_OR_RECEIPT_ASSERTION_FAILED';
  END IF;
  IF EXISTS (SELECT 1 FROM public.ns_sync_receipts WHERE client_event_id='9d000000-0000-4000-8000-000000000002') THEN
    RAISE EXCEPTION 'DUPLICATE_REGISTER_OPEN_LEFT_RECEIPT';
  END IF;
END
$cash_session_assertions$;

SET ROLE authenticated;
DO $cash_session_direct_write_guard$
BEGIN
  IF has_table_privilege(current_user,'public.ns_cash_sessions','INSERT')
     OR has_table_privilege(current_user,'public.ns_cash_sessions','UPDATE')
     OR has_table_privilege(current_user,'public.ns_expenses','INSERT')
     OR has_table_privilege(current_user,'public.ns_expenses','UPDATE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_CASH_SESSION_OR_EXPENSE_RPC';
  END IF;
END
$cash_session_direct_write_guard$;
RESET ROLE;


INSERT INTO public.ns_cash_registers(id,org_id,site_id,code,name,workstation_id,active)
VALUES (
  '9e000000-0000-4000-8000-000000000010',
  '20000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  'CI-CAISSE-SALE','Caisse ventes N2',NULL,true
);

SET ROLE authenticated;
DO $sale_sync$
DECLARE
  v_result jsonb;
  v_replay jsonb;
  v_sale_id uuid:='a2000000-0000-4000-8000-000000000001';
  v_pending_sale_id uuid:='a2000000-0000-4000-8000-000000000002';
  v_cash_session_id uuid:='9f000000-0000-4000-8000-000000000010';
  v_sale_event uuid:='a3000000-0000-4000-8000-000000000001';
  v_cancel_event uuid:='a3000000-0000-4000-8000-000000000003';
  v_rejected boolean:=false;
BEGIN
  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a3000000-0000-4000-8000-000000000000'::uuid,90,
    'cash_session','9f000000-0000-4000-8000-000000000010',
    'cash_session.opened',
    jsonb_build_object(
      'cash_session_id',v_cash_session_id,
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'register_id','9e000000-0000-4000-8000-000000000010',
      'register_name','Caisse ventes N2','opening_float_xaf',5000,'opened_at',now()
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'SALE_TEST_CASH_SESSION_NOT_OPENED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_sale_event,91,
    'sale',v_sale_id::text,'sale.created',
    jsonb_build_object(
      'sale_id',v_sale_id,'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'cash_session_id',v_cash_session_id,'sale_number','CI-SALE-N2-001',
      'description','Vente espèces stock CI','total_xaf',7000,
      'payment_method','cash','status','confirmed',
      'inventory_item_id','92000000-0000-4000-8000-000000000001',
      'stock_quantity',2.0,'created_at',now()
    )
  );
  IF v_result->>'status'<>'applied' OR v_result->'inventory_posting'->>'status'='awaiting_verified_provider_confirmation' THEN
    RAISE EXCEPTION 'CASH_SALE_NOT_POSTED_ATOMICALLY: %',v_result;
  END IF;

  v_replay:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_sale_event,91,
    'sale',v_sale_id::text,'sale.created',
    jsonb_build_object(
      'sale_id',v_sale_id,'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'cash_session_id',v_cash_session_id,'sale_number','CI-SALE-N2-001',
      'description','Vente espèces stock CI','total_xaf',7000,
      'payment_method','cash','status','confirmed',
      'inventory_item_id','92000000-0000-4000-8000-000000000001',
      'stock_quantity',2.0,'created_at',now()
    )
  );
  IF coalesce((v_replay->>'idempotent')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'CASH_SALE_IDENTICAL_REPLAY_NOT_IDEMPOTENT: %',v_replay;
  END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a3000000-0000-4000-8000-000000000002'::uuid,92,
    'sale',v_pending_sale_id::text,'sale.created',
    jsonb_build_object(
      'sale_id',v_pending_sale_id,'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'cash_session_id',v_cash_session_id,'sale_number','CI-SALE-N2-002',
      'description','Vente Mobile Money en attente','total_xaf',3000,
      'payment_method','mobile_money','status','pending',
      'inventory_item_id','92000000-0000-4000-8000-000000000001',
      'stock_quantity',1.5,'created_at',now()
    )
  );
  IF v_result->>'payment_status'<>'pending'
     OR v_result->>'server_status'<>'draft'
     OR v_result->'inventory_posting'->>'status'<>'awaiting_verified_provider_confirmation' THEN
    RAISE EXCEPTION 'MOBILE_MONEY_SALE_WAS_NOT_LEFT_PENDING: %',v_result;
  END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,v_cancel_event,93,
    'sale',v_pending_sale_id::text,'sale.mobile_money_cancelled',
    jsonb_build_object(
      'sale_id',v_pending_sale_id,'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'expected_status','pending','reason','Annulation avant confirmation opérateur',
      'cancelled_at',now()+interval '1 minute'
    )
  );
  IF v_result->>'status'<>'applied'
     OR v_result->'result'->>'status'<>'cancelled'
     OR v_result->'result'->>'server_status'<>'voided'
     OR v_result->'result'->>'payment_status'<>'failed'
     OR coalesce((v_result->'result'->>'reservation_released')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'PENDING_MOBILE_MONEY_SALE_NOT_CANCELLED: %',v_result;
  END IF;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      'a3000000-0000-4000-8000-000000000004'::uuid,94,
      'sale',v_sale_id::text,'sale.mobile_money_cancelled',
      jsonb_build_object(
        'sale_id',v_sale_id,'org_id','20000000-0000-4000-8000-000000000001',
        'site_id','30000000-0000-4000-8000-000000000001',
        'expected_status','pending','reason','Tentative après paiement final',
        'cancelled_at',now()+interval '2 minutes'
      )
    );
    RAISE EXCEPTION 'CONFIRMED_CASH_SALE_WAS_ALLOWED_TO_CANCEL';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'NAXA_SALE_NOT_PENDING' THEN RAISE; END IF;
  END;
END
$sale_sync$;
RESET ROLE;

DO $sale_assertions$
DECLARE
  v_sale_status text; v_payment_status text; v_quantity numeric(14,3);
  v_cost bigint; v_movement_count integer; v_receipt_count integer;
  v_pending_status text; v_pending_payment text;
BEGIN
  SELECT status,cost_of_goods_xaf INTO v_sale_status,v_cost
  FROM public.ns_sales WHERE id='a2000000-0000-4000-8000-000000000001';
  SELECT status INTO v_payment_status FROM public.ns_payments WHERE sale_id='a2000000-0000-4000-8000-000000000001';
  SELECT quantity INTO v_quantity FROM public.ns_inventory_items
  WHERE id='92000000-0000-4000-8000-000000000001';
  SELECT count(*) INTO v_movement_count FROM public.ns_inventory_movements
  WHERE idempotency_key='a3000000-0000-4000-8000-000000000001';
  SELECT count(*) INTO v_receipt_count FROM public.ns_sync_receipts
  WHERE client_event_id='a3000000-0000-4000-8000-000000000001';
  SELECT status INTO v_pending_status FROM public.ns_sales
  WHERE id='a2000000-0000-4000-8000-000000000002';
  SELECT status INTO v_pending_payment FROM public.ns_payments
  WHERE sale_id='a2000000-0000-4000-8000-000000000002';

  IF v_sale_status<>'posted' OR v_payment_status<>'confirmed'
     OR v_quantity<>10.5 OR v_cost<>3400 OR v_movement_count<>1 OR v_receipt_count<>1 THEN
    RAISE EXCEPTION 'CASH_SALE_STOCK_PAYMENT_OR_ACCOUNTING_ASSERTION_FAILED';
  END IF;
  IF v_pending_status<>'voided' OR v_pending_payment<>'failed' THEN
    RAISE EXCEPTION 'MOBILE_MONEY_CANCELLATION_FINAL_STATE_INVALID';
  END IF;
END
$sale_assertions$;

SET ROLE authenticated;
DO $sale_direct_write_guard$
BEGIN
  IF has_function_privilege(current_user,
       'public.ns_create_sale(uuid,uuid,uuid,uuid,uuid,text,text,bigint,text,text,uuid,numeric,timestamptz,uuid)','EXECUTE')
     OR has_function_privilege(current_user,
       'public.ns_cancel_pending_mobile_money_sale(uuid,uuid,uuid,text,text,timestamptz)','EXECUTE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_ATOMIC_SALE_RECEIPTS';
  END IF;
  IF has_table_privilege(current_user,'public.ns_sales','INSERT')
     OR has_table_privilege(current_user,'public.ns_sales','UPDATE')
     OR has_table_privilege(current_user,'public.ns_payments','INSERT')
     OR has_table_privilege(current_user,'public.ns_payments','UPDATE')
     OR has_table_privilege(current_user,'public.ns_sale_lines','INSERT')
     OR has_table_privilege(current_user,'public.ns_sale_lines','UPDATE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_SALE_OR_PAYMENT_RPC';
  END IF;
END
$sale_direct_write_guard$;
RESET ROLE;

DO $sale_server_execute_guard$
BEGIN
  IF NOT has_function_privilege('service_role',
       'public.ns_create_sale(uuid,uuid,uuid,uuid,uuid,text,text,bigint,text,text,uuid,numeric,timestamptz,uuid)','EXECUTE')
     OR NOT has_function_privilege('service_role',
       'public.ns_cancel_pending_mobile_money_sale(uuid,uuid,uuid,text,text,timestamptz)','EXECUTE') THEN
    RAISE EXCEPTION 'SERVICE_ROLE_CANNOT_EXECUTE_SALE_HANDLERS';
  END IF;
END
$sale_server_execute_guard$;


SET ROLE authenticated;
DO $customer_management_staff_sync$
DECLARE
  v_result jsonb;
  v_replay jsonb;
  v_event timestamptz:=now()+interval '20 hours';
BEGIN
  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a4000000-0000-4000-8000-000000000001'::uuid,160,
    'customer','90000000-0000-4000-8000-000000000001','customer.updated',
    jsonb_build_object(
      'customer_id','90000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'display_name','Customer A1 updated','phone_contact','690000011',
      'contact_consent',false,'address_line','Adresse mise à jour',
      'neighborhood','Akwa','landmark','près du carrefour',
      'notes_private','','expected_version',1
    )
  );
  IF v_result->>'status'<>'applied'
     OR (v_result->'result'->>'revision')::integer<>2 THEN
    RAISE EXCEPTION 'CUSTOMER_UPDATE_NOT_VERSIONED: %',v_result;
  END IF;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      'a4000000-0000-4000-8000-000000000002'::uuid,161,
      'customer','90000000-0000-4000-8000-000000000001','customer.updated',
      jsonb_build_object(
        'customer_id','90000000-0000-4000-8000-000000000001',
        'org_id','20000000-0000-4000-8000-000000000001',
        'site_id','30000000-0000-4000-8000-000000000001',
        'display_name','Stale customer edit','phone_contact','690000012',
        'contact_consent',false,'address_line','','neighborhood','',
        'landmark','','notes_private','','expected_version',1
      )
    );
    RAISE EXCEPTION 'STALE_CUSTOMER_VERSION_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'NAXA_CUSTOMER_VERSION_CONFLICT' THEN RAISE; END IF;
  END;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a4000000-0000-4000-8000-000000000003'::uuid,162,
    'quote','a5000000-0000-4000-8000-000000000001','quote.created',
    jsonb_build_object(
      'record_id','a5000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'record_type','quote','reference','DEV-CI-001','title','Devis de test',
      'counterparty','Client CI','amount_xaf',25000,'paid_xaf',0,
      'status','draft','metadata_json',jsonb_build_object('origin','runtime-ci')
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'MANAGEMENT_RECORD_CREATE_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a4000000-0000-4000-8000-000000000004'::uuid,163,
    'quote','a5000000-0000-4000-8000-000000000001','quote.status_changed',
    jsonb_build_object(
      'record_id','a5000000-0000-4000-8000-000000000001',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'record_type','quote','from_status','draft','to_status','approved',
      'reason','Validation CI','expected_version',1,'metadata_json_delta','{}'::jsonb
    )
  );
  IF v_result->>'status'<>'applied' OR v_result->'result'->>'status'<>'approved' THEN
    RAISE EXCEPTION 'MANAGEMENT_RECORD_TRANSITION_NOT_APPLIED: %',v_result;
  END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a4000000-0000-4000-8000-000000000005'::uuid,164,
    'appointment_waitlist','a5000000-0000-4000-8000-000000000002','appointment_waitlist.created',
    jsonb_build_object(
      'record_id','a5000000-0000-4000-8000-000000000002',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'record_type','appointment_waitlist','reference','WL-CI-001',
      'title','Pressing standard','counterparty','Client liste attente',
      'amount_xaf',0,'paid_xaf',0,'status','open','metadata_json','{}'::jsonb
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'WAITLIST_CREATE_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a4000000-0000-4000-8000-000000000006'::uuid,165,
    'appointment','a5000000-0000-4000-8000-000000000003','appointment.created_from_waitlist',
    jsonb_build_object(
      'appointment_id','a5000000-0000-4000-8000-000000000003',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'waitlist_record_id','a5000000-0000-4000-8000-000000000002',
      'workstation_id',null,'starts_at',now()+interval '10 hours',
      'duration_minutes',30,'deposit_xaf',500,'reason','Confirmation liste attente CI',
      'assigned_member_id','60000000-0000-4000-8000-000000000001'
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'WAITLIST_TO_APPOINTMENT_NOT_ATOMIC: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a4000000-0000-4000-8000-000000000007'::uuid,166,
    'staff_clock_in','a5000000-0000-4000-8000-000000000010','staff_clock_in.recorded',
    jsonb_build_object(
      'time_event_id','a5000000-0000-4000-8000-000000000010',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'staff_member_id','60000000-0000-4000-8000-000000000001',
      'staff_name_snapshot','Collaborateur CI','event_type','staff_clock_in',
      'occurred_at',v_event
    )
  );
  IF v_result->>'status'<>'applied' OR (v_result->'result'->>'sequence_no')::bigint<>1 THEN
    RAISE EXCEPTION 'STAFF_CLOCK_IN_NOT_APPLIED: %',v_result;
  END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a4000000-0000-4000-8000-000000000008'::uuid,167,
    'staff_break_start','a5000000-0000-4000-8000-000000000011','staff_break_start.recorded',
    jsonb_build_object(
      'time_event_id','a5000000-0000-4000-8000-000000000011',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'staff_member_id','60000000-0000-4000-8000-000000000001',
      'staff_name_snapshot','Collaborateur CI','event_type','staff_break_start',
      'occurred_at',v_event+interval '1 minute'
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'STAFF_BREAK_START_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a4000000-0000-4000-8000-000000000009'::uuid,168,
    'staff_break_end','a5000000-0000-4000-8000-000000000012','staff_break_end.recorded',
    jsonb_build_object(
      'time_event_id','a5000000-0000-4000-8000-000000000012',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'staff_member_id','60000000-0000-4000-8000-000000000001',
      'staff_name_snapshot','Collaborateur CI','event_type','staff_break_end',
      'occurred_at',v_event+interval '2 minutes'
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'STAFF_BREAK_END_NOT_APPLIED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000001'::uuid,
    'a4000000-0000-4000-8000-00000000000a'::uuid,169,
    'staff_clock_out','a5000000-0000-4000-8000-000000000013','staff_clock_out.recorded',
    jsonb_build_object(
      'time_event_id','a5000000-0000-4000-8000-000000000013',
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'staff_member_id','60000000-0000-4000-8000-000000000001',
      'staff_name_snapshot','Collaborateur CI','event_type','staff_clock_out',
      'occurred_at',v_event+interval '3 minutes'
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'STAFF_CLOCK_OUT_NOT_APPLIED: %',v_result; END IF;

  BEGIN
    PERFORM public.ns_apply_sync_event(
      '20000000-0000-4000-8000-000000000001'::uuid,
      '30000000-0000-4000-8000-000000000001'::uuid,null,
      '80000000-0000-4000-8000-000000000001'::uuid,
      'a4000000-0000-4000-8000-00000000000b'::uuid,170,
      'staff_break_end','a5000000-0000-4000-8000-000000000014','staff_break_end.recorded',
      jsonb_build_object(
        'time_event_id','a5000000-0000-4000-8000-000000000014',
        'org_id','20000000-0000-4000-8000-000000000001',
        'site_id','30000000-0000-4000-8000-000000000001',
        'staff_member_id','60000000-0000-4000-8000-000000000001',
        'staff_name_snapshot','Collaborateur CI','event_type','staff_break_end',
        'occurred_at',v_event+interval '4 minutes'
      )
    );
    RAISE EXCEPTION 'INVALID_STAFF_TIME_SEQUENCE_WAS_ACCEPTED';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'NAXA_STAFF_TIME_SEQUENCE_INVALID' THEN RAISE; END IF;
  END;
END
$customer_management_staff_sync$;
RESET ROLE;

DO $customer_management_staff_assertions$
DECLARE v_customer_revision integer; v_quote_status text; v_quote_events integer;
        v_waitlist_status text; v_appointment_status text; v_staff_events integer;
BEGIN
  SELECT revision INTO v_customer_revision FROM public.ns_customers
   WHERE id='90000000-0000-4000-8000-000000000001';
  IF v_customer_revision<>2 THEN RAISE EXCEPTION 'CUSTOMER_REVISION_NOT_INCREMENTED'; END IF;
  SELECT status INTO v_quote_status FROM public.ns_management_records
   WHERE id='a5000000-0000-4000-8000-000000000001';
  SELECT count(*) INTO v_quote_events FROM public.ns_management_record_events
   WHERE record_id='a5000000-0000-4000-8000-000000000001';
  IF v_quote_status<>'approved' OR v_quote_events<>2 THEN
    RAISE EXCEPTION 'MANAGEMENT_RECORD_HISTORY_INVALID';
  END IF;
  SELECT status INTO v_waitlist_status FROM public.ns_management_records
   WHERE id='a5000000-0000-4000-8000-000000000002';
  SELECT status INTO v_appointment_status FROM public.ns_appointments
   WHERE id='a5000000-0000-4000-8000-000000000003';
  IF v_waitlist_status<>'booked' OR v_appointment_status<>'booked' THEN
    RAISE EXCEPTION 'WAITLIST_APPOINTMENT_CONVERSION_NOT_COMMITTED_TOGETHER';
  END IF;
  SELECT count(*) INTO v_staff_events FROM public.ns_staff_time_events
   WHERE staff_member_id='60000000-0000-4000-8000-000000000001';
  IF v_staff_events<>4 THEN RAISE EXCEPTION 'STAFF_TIME_SEQUENCE_LEDGER_INVALID: %',v_staff_events; END IF;
END
$customer_management_staff_assertions$;

-- Switch to the organization promoter for inter-site transfer operations.
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',false);
SELECT set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","session_id":"ci-session-promoter"}',false);
SET ROLE authenticated;
DO $inventory_transfer_sync$
DECLARE
  v_result jsonb; v_replay jsonb; v_transfer uuid:='a6000000-0000-4000-8000-000000000001';
  v_source_qty numeric(14,3); v_destination_qty numeric(14,3);
  v_destination_item uuid; v_movements integer;
BEGIN
  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000002'::uuid,
    'a7000000-0000-4000-8000-000000000001'::uuid,200,
    'inventory_transfer',v_transfer::text,'inventory_transfer.requested',
    jsonb_build_object(
      'transfer_id',v_transfer,'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'source_site_id','30000000-0000-4000-8000-000000000001',
      'destination_site_id','30000000-0000-4000-8000-000000000002',
      'inventory_item_id','92000000-0000-4000-8000-000000000001',
      'sku_snapshot','CI-STOCK-001','unit','pièce','quantity',2.5,
      'reference','TRF-CI-001','requested_at',now()
    )
  );
  IF v_result->>'status'<>'applied' THEN RAISE EXCEPTION 'TRANSFER_REQUEST_NOT_CREATED: %',v_result; END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000002'::uuid,
    'a7000000-0000-4000-8000-000000000002'::uuid,201,
    'inventory_transfer',v_transfer::text,'inventory_transfer.status_changed',
    jsonb_build_object(
      'record_id',v_transfer,'transfer_id',v_transfer,
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'source_site_id','30000000-0000-4000-8000-000000000001',
      'destination_site_id','30000000-0000-4000-8000-000000000002',
      'from_status','open','to_status','approved','reason','Approbation CI',
      'expected_version',1,'transitioned_at',now()
    )
  );
  IF v_result->>'status'<>'applied' OR v_result->'result'->>'status'<>'approved' THEN
    RAISE EXCEPTION 'TRANSFER_APPROVAL_NOT_APPLIED: %',v_result;
  END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000002'::uuid,null,
    '80000000-0000-4000-8000-000000000002'::uuid,
    'a7000000-0000-4000-8000-000000000003'::uuid,202,
    'inventory_transfer',v_transfer::text,'inventory_transfer.received_at_destination',
    jsonb_build_object(
      'transfer_id',v_transfer,'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000002',
      'source_site_id','30000000-0000-4000-8000-000000000001',
      'destination_site_id','30000000-0000-4000-8000-000000000002',
      'inventory_item_id','92000000-0000-4000-8000-000000000001',
      'sku_snapshot','CI-STOCK-001','unit','pièce','quantity',2.5,
      'expected_version',2,'reason','Réception CI','received_at',now()+interval '1 minute'
    )
  );
  IF v_result->>'status'<>'applied' OR v_result->'result'->>'status'<>'received' THEN
    RAISE EXCEPTION 'TRANSFER_RECEIPT_NOT_APPLIED: %',v_result;
  END IF;
  v_destination_item:=(v_result->'result'->>'destination_inventory_item_id')::uuid;

  v_replay:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000002'::uuid,null,
    '80000000-0000-4000-8000-000000000002'::uuid,
    'a7000000-0000-4000-8000-000000000004'::uuid,203,
    'inventory_transfer',v_transfer::text,'inventory_transfer.received_at_destination',
    jsonb_build_object(
      'transfer_id',v_transfer,'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000002',
      'source_site_id','30000000-0000-4000-8000-000000000001',
      'destination_site_id','30000000-0000-4000-8000-000000000002',
      'inventory_item_id','92000000-0000-4000-8000-000000000001',
      'sku_snapshot','CI-STOCK-001','unit','pièce','quantity',2.5,
      'expected_version',2,'reason','Réception CI','received_at',now()+interval '1 minute'
    )
  );
  IF v_replay->>'status'<>'applied'
     OR coalesce((v_replay->'result'->>'idempotent')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'TRANSFER_RECEIPT_REPLAY_NOT_IDEMPOTENT: %',v_replay;
  END IF;

  v_result:=public.ns_apply_sync_event(
    '20000000-0000-4000-8000-000000000001'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid,null,
    '80000000-0000-4000-8000-000000000002'::uuid,
    'a7000000-0000-4000-8000-000000000005'::uuid,204,
    'inventory_transfer',v_transfer::text,'inventory_transfer.status_changed',
    jsonb_build_object(
      'record_id',v_transfer,'transfer_id',v_transfer,
      'org_id','20000000-0000-4000-8000-000000000001',
      'site_id','30000000-0000-4000-8000-000000000001',
      'source_site_id','30000000-0000-4000-8000-000000000001',
      'destination_site_id','30000000-0000-4000-8000-000000000002',
      'from_status','approved','to_status','received','reason','Réception CI',
      'expected_version',2,'transitioned_at',now()+interval '1 minute'
    )
  );
  IF v_result->>'status'<>'applied' OR coalesce((v_result->'result'->>'idempotent')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'DUPLICATE_GENERIC_TRANSFER_STATUS_NOT_IDEMPOTENT: %',v_result;
  END IF;

  SELECT quantity INTO v_source_qty FROM public.ns_inventory_items
   WHERE id='92000000-0000-4000-8000-000000000001';
  SELECT quantity INTO v_destination_qty FROM public.ns_inventory_items
   WHERE id=v_destination_item;
  SELECT count(*) INTO v_movements FROM public.ns_inventory_movements
   WHERE reason like '%'||v_transfer::text;
  IF v_source_qty<>8.0 OR v_destination_qty<>2.5 OR v_movements<>2 THEN
    RAISE EXCEPTION 'TRANSFER_STOCK_LEDGER_NOT_ATOMIC: source %, destination %, movement_rows %',
      v_source_qty,v_destination_qty,v_movements;
  END IF;
END
$inventory_transfer_sync$;
RESET ROLE;

-- Restore the site-scoped manager session for device revocation checks.
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',false);
SELECT set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","session_id":"ci-session-a"}',false);

UPDATE public.ns_devices SET revoked_at=now() WHERE id='80000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
DO $revocation$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.ns_customers;
  IF v_count <> 0 THEN RAISE EXCEPTION 'REVOKED_DEVICE_STILL_HAS_DATA_ACCESS'; END IF;
  IF public.ns_current_account_id() IS NOT NULL THEN RAISE EXCEPTION 'REVOKED_DEVICE_SESSION_STILL_VALID'; END IF;
END
$revocation$;
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","session_id":"stale-session"}',false);
SET ROLE authenticated;
DO $stale$
BEGIN
  IF public.ns_current_account_id() IS NOT NULL THEN RAISE EXCEPTION 'STALE_DEVICE_SESSION_WAS_ACCEPTED'; END IF;
END
$stale$;
RESET ROLE;

SET ROLE authenticated;
DO $financial_server_write_guard$
BEGIN
  BEGIN
    INSERT INTO public.ns_commission_policy_versions DEFAULT VALUES;
    RAISE EXCEPTION 'RLS_ALLOWED_CLIENT_COMMISSION_POLICY_WRITE';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.ns_fiscal_policies DEFAULT VALUES;
    RAISE EXCEPTION 'RLS_ALLOWED_CLIENT_FISCAL_POLICY_WRITE';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    SELECT 1 FROM public.ns_payment_provider_accounts LIMIT 1;
    RAISE EXCEPTION 'RLS_ALLOWED_CLIENT_PROVIDER_ACCOUNT_READ';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    SELECT 1 FROM public.ns_payment_provider_events LIMIT 1;
    RAISE EXCEPTION 'RLS_ALLOWED_CLIENT_PROVIDER_EVENT_READ';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  IF has_table_privilege(current_user,'public.ns_services','INSERT')
     OR has_table_privilege(current_user,'public.ns_services','UPDATE')
     OR has_table_privilege(current_user,'public.ns_services','DELETE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_SERVICE_DOMAIN_RPC';
  END IF;
  IF has_table_privilege(current_user,'public.ns_customers','INSERT')
     OR has_table_privilege(current_user,'public.ns_customers','UPDATE')
     OR has_table_privilege(current_user,'public.ns_customers','DELETE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_CUSTOMER_DOMAIN_RPC';
  END IF;
  IF has_table_privilege(current_user,'public.ns_management_records','INSERT')
     OR has_table_privilege(current_user,'public.ns_management_records','UPDATE')
     OR has_table_privilege(current_user,'public.ns_management_record_events','INSERT')
     OR has_table_privilege(current_user,'public.ns_staff_time_events','INSERT')
     OR has_table_privilege(current_user,'public.ns_inventory_transfers','INSERT')
     OR has_table_privilege(current_user,'public.ns_inventory_transfers','UPDATE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_MANAGEMENT_STAFF_OR_TRANSFER_RPC';
  END IF;
  IF has_function_privilege(current_user,
       'public.ns_update_customer(uuid,uuid,uuid,text,text,boolean,text,text,text,numeric,numeric,timestamptz,text,integer)','EXECUTE')
     OR has_function_privilege(current_user,
       'public.ns_create_management_record(uuid,uuid,uuid,uuid,text,text,text,text,bigint,bigint,timestamptz,text,jsonb)','EXECUTE')
     OR has_function_privilege(current_user,
       'public.ns_record_staff_time_event(uuid,uuid,uuid,uuid,uuid,text,text,timestamptz)','EXECUTE')
     OR has_function_privilege(current_user,
       'public.ns_receive_inventory_transfer(uuid,uuid,uuid,uuid,uuid,uuid,text,text,numeric,integer,text,timestamptz)','EXECUTE') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_N2_MUTATION_RECEIPTS';
  END IF;
  IF NOT has_function_privilege(current_user,
       'public.ns_apply_sync_event(uuid,uuid,uuid,uuid,uuid,bigint,text,text,text,jsonb)','EXECUTE') THEN
    RAISE EXCEPTION 'AUTHENTICATED_CANNOT_EXECUTE_ATOMIC_SYNC_GATEWAY';
  END IF;
  IF has_table_privilege(current_user,'public.ns_customer_followups','INSERT')
     OR has_table_privilege(current_user,'public.ns_customer_followups','UPDATE')
     OR has_table_privilege(current_user,'public.ns_customer_followup_events','INSERT')
     OR has_table_privilege(current_user,'public.ns_support_requests','INSERT') THEN
    RAISE EXCEPTION 'CLIENT_CAN_BYPASS_CRM_OR_SUPPORT_DOMAIN_RPC';
  END IF;
END
$financial_server_write_guard$;
RESET ROLE;

ROLLBACK;
