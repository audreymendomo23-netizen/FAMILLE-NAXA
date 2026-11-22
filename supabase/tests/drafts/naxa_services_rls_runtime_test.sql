-- Runtime RLS tests for disposable PostgreSQL CI only; uses synthetic fixtures.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users(id) VALUES ('10000000-0000-4000-8000-000000000001');
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
VALUES ('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','CI-USER-A','ci-user-a@example.invalid','active',false);
INSERT INTO public.ns_members(id,org_id,account_id,display_name,role_code,status)
VALUES ('60000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','Fixture Site Manager','site_manager','active');
INSERT INTO public.ns_member_scopes(id,org_id,member_id,scope_type,scope_id,site_id,workstation_id,can_read,can_operate,can_manage)
VALUES ('70000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','site','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001',NULL,true,true,true);
INSERT INTO public.ns_devices(id,account_id,installation_id,platform,label,remember_device,session_id)
VALUES ('80000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','ci-installation-a','android','Disposable CI device',true,'ci-session-a');
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
