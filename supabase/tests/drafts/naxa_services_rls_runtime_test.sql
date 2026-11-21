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
INSERT INTO public.ns_sales(id,org_id,site_id,sale_number,subtotal_xaf,discount_xaf,total_xaf,status,created_by,customer_id)
VALUES ('a0000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','CI-SALE-001',1000,0,1000,'posted','60000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001');
COMMIT;

BEGIN;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',false);
SELECT set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","session_id":"ci-session-a"}',false);
SET ROLE authenticated;
DO $rls$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.ns_customers;
  IF v_count <> 1 THEN RAISE EXCEPTION 'RLS_SITE_ISOLATION_FAILED: expected 1 customer, got %',v_count; END IF;
  IF EXISTS (SELECT 1 FROM public.ns_customers WHERE id IN ('90000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000003')) THEN RAISE EXCEPTION 'RLS_CROSS_SITE_OR_TENANT_READ_FAILED'; END IF;
  IF public.ns_current_account_id() <> '50000000-0000-4000-8000-000000000001'::uuid THEN RAISE EXCEPTION 'DEVICE_SESSION_BINDING_FAILED'; END IF;
  IF public.ns_can_manage_org('20000000-0000-4000-8000-000000000001'::uuid) THEN RAISE EXCEPTION 'SITE_MANAGER_ESCALATED_TO_ORGANIZATION_MANAGER'; END IF;
  IF has_table_privilege(current_user,'public.ns_payments','UPDATE') THEN RAISE EXCEPTION 'CLIENT_CAN_UPDATE_PAYMENT_STATUS'; END IF;
  IF has_table_privilege(current_user,'public.ns_referrals','SELECT') OR has_table_privilege(current_user,'public.ns_referrals','INSERT') OR has_table_privilege(current_user,'public.ns_referral_rewards','UPDATE') THEN RAISE EXCEPTION 'CLIENT_HAS_DIRECT_REFERRAL_TABLE_ACCESS'; END IF;
  IF has_table_privilege(current_user,'public.ns_sync_receipts','SELECT') OR has_table_privilege(current_user,'public.ns_sync_conflicts','INSERT') OR has_table_privilege(current_user,'public.ns_notification_outbox','SELECT') THEN RAISE EXCEPTION 'CLIENT_HAS_SERVER_ONLY_SYNC_OR_NOTIFICATION_ACCESS'; END IF;
  IF NOT has_table_privilege('service_role','public.ns_referrals','SELECT') OR NOT has_table_privilege('service_role','public.ns_sync_receipts','SELECT') THEN RAISE EXCEPTION 'SERVER_ROLE_GRANTS_MISSING'; END IF;
END
$rls$;

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
ROLLBACK;
