-- Disposable database; use only synthetic destination and evidence.
begin;
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000071'),('10000000-0000-4000-8000-000000000072');
insert into public.ns_organizations(id,display_name,business_mode,status) values ('20000000-0000-4000-8000-000000000071','Subscription CI','solo','active');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,status,password_change_required) values ('50000000-0000-4000-8000-000000000071','10000000-0000-4000-8000-000000000071','SUB-CI','sub-ci@example.invalid','active',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code,status) values ('60000000-0000-4000-8000-000000000071','20000000-0000-4000-8000-000000000071','50000000-0000-4000-8000-000000000071','CI payer','promoter','active');
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000071','60000000-0000-4000-8000-000000000071','organization','20000000-0000-4000-8000-000000000071',true,true,true);
insert into public.ns_devices(account_id,installation_id,platform,label,remember_device,session_id) values ('50000000-0000-4000-8000-000000000071','sub-ci','android','CI payer',true,'sub-ci-session');
insert into public.ns_subscription_destinations values ('mtn_momo','123456','CI ONLY','237690000072',true);
insert into public.ns_subscription_admin_devices(id,auth_user_id,channel,session_id,destination_reference,sms_capture_allowed,active) values ('80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','mtn_momo','admin-ci','237690000072',true,true);
do $f$ begin
 if public.ns_subscription_amount('ACCESS',1,date '2027-04-30')<>3000 or public.ns_subscription_amount('PREMIUM',12,date '2027-05-01')<>150000 then raise exception 'TARIFF_BOUNDARY'; end if;
end $f$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000071',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000071","session_id":"sub-ci-session"}',true);
set local role authenticated;
do $f$
declare i jsonb; j jsonb; begin
 if has_table_privilege(current_user,'public.ns_subscription_credit_proofs','INSERT') or has_function_privilege(current_user,'public.ns_subscription_confirm_credit(uuid,uuid,uuid,text,text,text,text,bigint,text,timestamptz,timestamptz,text,text)','EXECUTE') then raise exception 'PAYER_CAN_CONFIRM'; end if;
 begin perform public.ns_subscription_list('20000000-0000-4000-8000-000000000001'); raise exception 'CROSS_TENANT_ALLOWED'; exception when insufficient_privilege then null; end;
 if public.ns_erp_access_reason('20000000-0000-4000-8000-000000000071') is distinct from 'trial' then raise exception 'TRIAL_ACCESS_MISSING'; end if;
 i:=public.ns_subscription_create('20000000-0000-4000-8000-000000000071','ACCESS',1,'mtn_momo');
 if i->>'status' is distinct from 'pending' then raise exception 'INVALID_INTENT'; end if;
 begin
  perform public.ns_subscription_cancel((i->>'id')::uuid,false);
  raise exception 'CANCEL_WITHOUT_ATTESTATION';
 exception when raise_exception then if sqlerrm<>'NS_NO_PAYMENT_CONFIRMATION_REQUIRED' then raise; end if; end;
 j:=public.ns_subscription_cancel((i->>'id')::uuid,true);
 if j->>'status' is distinct from 'cancelled' then raise exception 'CANCEL_NOT_RECORDED'; end if;
 j:=public.ns_subscription_cancel((i->>'id')::uuid,true);
 if j->>'status' is distinct from 'cancelled' then raise exception 'CANCEL_NOT_IDEMPOTENT'; end if;
 i:=public.ns_subscription_create('20000000-0000-4000-8000-000000000071','ACCESS',1,'mtn_momo');
 if i->>'status' is distinct from 'pending' then raise exception 'NEW_INTENT_NOT_CREATED'; end if;
 if has_function_privilege(current_user,'public.ns_subscription_declare(uuid,text,text,timestamptz,text)','EXECUTE') then raise exception 'CLIENT_CAN_FABRICATE_HASH'; end if;
 j:=public.ns_subscription_declare_sms((i->>'id')::uuid,'Your payment of '||(i->>'amount_xaf')||' XAF to CI ONLY (237690000072) was completed at '||to_char(now() at time zone 'Africa/Douala','YYYY-MM-DD HH24:MI:SS')||'. Financial transaction id: FIXTURETX71','690000071',null);
 if j->>'status' is distinct from 'submitted' or j->>'receipt_number' is not null then raise exception 'SINGLE_PROOF_CONFIRMED'; end if;
 begin
  perform public.ns_subscription_cancel((i->>'id')::uuid,true);
  raise exception 'DECLARED_PAYMENT_CANCELLED';
 exception when raise_exception then if sqlerrm<>'NS_PAYMENT_ALREADY_DECLARED' then raise; end if; end;
end $f$;
reset role;
do $f$
declare i public.ns_subscription_intents%rowtype; r jsonb; r2 jsonb; begin
 select * into i from public.ns_subscription_intents where org_id='20000000-0000-4000-8000-000000000071' and status='submitted';
 if exists(select 1 from public.ns_subscriptions where org_id=i.org_id) then raise exception 'PREMATURE_SUBSCRIPTION'; end if;
 begin
  perform public.ns_subscription_confirm_credit(i.id,'80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci','mtn_momo','FIXTURETX71','237690000072',i.amount_xaf+1,'690000071',now(),now(),repeat('b',64),'MobileMoney');
  raise exception 'WRONG_AMOUNT_ACCEPTED';
 exception when raise_exception then if sqlerrm<>'NS_CREDIT_PROOF_MISMATCH' then raise; end if; end;
 r:=public.ns_subscription_confirm_credit(i.id,'80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci','mtn_momo','FIXTURETX71','237690000072',i.amount_xaf,'690000071',now(),now(),repeat('b',64),'MobileMoney');
 r2:=public.ns_subscription_confirm_credit(i.id,'80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci','mtn_momo','FIXTURETX71','237690000072',i.amount_xaf,'690000071',now(),now(),repeat('b',64),'MobileMoney');
 if r->>'status' is distinct from 'confirmed' or r->>'receipt_number' is null or r<>r2 or (select count(*) from public.ns_subscription_credit_proofs where intent_id=i.id)<>1 then raise exception 'CONFIRMATION_OR_IDEMPOTENCE_FAILED'; end if;
 if exists(select 1 from public.ns_payments where org_id=i.org_id) then raise exception 'SUBSCRIPTION_LEAKED_INTO_TENANT_CASH'; end if;
end $f$;
-- ACCESS is unavailable to a network at the point of a new payment request.
update public.ns_organizations set business_mode='multi_site_network' where id='20000000-0000-4000-8000-000000000071';
set local role authenticated;
do $f$ begin
 begin perform public.ns_subscription_create('20000000-0000-4000-8000-000000000071','ACCESS',1,'mtn_momo'); raise exception 'NETWORK_ACCESS_ALLOWED';
 exception when raise_exception then if sqlerrm<>'NS_PREMIUM_REQUIRED' then raise; end if; end;
end $f$;
reset role;
update public.ns_organizations set business_mode='solo' where id='20000000-0000-4000-8000-000000000071';
-- Credit may arrive first; it must remain pending without a debit declaration.
set local role authenticated;
do $f$ declare j jsonb; begin
 j:=public.ns_subscription_create('20000000-0000-4000-8000-000000000071','ACCESS',1,'mtn_momo');
 if j->>'status' is distinct from 'pending' then raise exception 'RENEWAL_INTENT_NOT_PENDING'; end if;
end $f$;
reset role;
do $f$ declare i public.ns_subscription_intents%rowtype; v jsonb; begin
 select * into i from public.ns_subscription_intents where org_id='20000000-0000-4000-8000-000000000071' and status='pending';
 v:=public.ns_subscription_ingest_credit('80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci','mtn_momo','RENEWALTX71','237690000072',i.amount_xaf,'690000071',now(),now(),repeat('c',64),'MobileMoney');
 if v->>'status' is distinct from 'pending' then raise exception 'CREDIT_ONLY_ACTIVATED'; end if;
end $f$;
set local role authenticated;
do $f$ declare i jsonb; v jsonb; begin
 select item into i from jsonb_array_elements(public.ns_subscription_list('20000000-0000-4000-8000-000000000071')->'intents') item where item->>'status'='pending';
 v:=public.ns_subscription_declare_sms((i->>'id')::uuid,'Your payment of '||(i->>'amount_xaf')||' XAF to CI ONLY (237690000072) was completed at '||to_char(now() at time zone 'Africa/Douala','YYYY-MM-DD HH24:MI:SS')||'. Financial transaction id: RENEWALTX71','690000071',null);
 if v->>'status' is distinct from 'confirmed' then raise exception 'CREDIT_FIRST_MATCH_FAILED: %',v; end if;
end $f$;
reset role;
do $f$ begin
 if not exists(select 1 from public.ns_subscription_credit_candidates where transaction_reference='RENEWALTX71' and status='matched') then raise exception 'CREDIT_CANDIDATE_NOT_CONSUMED'; end if;
end $f$;
-- Orange: actual debit parser + independent beneficiary credit + receipt.
insert into public.ns_subscription_destinations values ('orange_money','654321','CI ORANGE','237690000073',true);
insert into public.ns_subscription_admin_devices(id,auth_user_id,channel,session_id,destination_reference,sms_capture_allowed,active) values ('80000000-0000-4000-8000-000000000073','10000000-0000-4000-8000-000000000072','orange_money','admin-ci','237690000073',true,true);
set local role authenticated;
do $f$ declare i jsonb; j jsonb; begin
 i:=public.ns_subscription_create('20000000-0000-4000-8000-000000000071','ACCESS',1,'orange_money');
 j:=public.ns_subscription_declare_sms((i->>'id')::uuid,'Paiement de CI ORANGE reussi par 237690000071 Fixture. ID transaction: OR.FIXTURE71, montant: '||(i->>'amount_xaf')||' FCFA','690000071',now());
 if j->>'status' is distinct from 'submitted' or j->>'receipt_number' is not null then raise exception 'ORANGE_DEBIT_ALONE_CONFIRMED'; end if;
end $f$;
reset role;
do $f$ declare i public.ns_subscription_intents%rowtype; v jsonb; begin
 select * into i from public.ns_subscription_intents where org_id='20000000-0000-4000-8000-000000000071' and status='submitted';
 begin perform public.ns_subscription_ingest_credit('80000000-0000-4000-8000-000000000073','10000000-0000-4000-8000-000000000072','wrong-session','orange_money','ORFIXTURE71','237690000073',i.amount_xaf,'690000071',now(),now(),repeat('e',64),'OrangeMoney'); raise exception 'STALE_DEVICE_ACCEPTED'; exception when insufficient_privilege then null; end;
 begin perform public.ns_subscription_ingest_credit('80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci','orange_money','ORFIXTURE71','237690000073',i.amount_xaf,'690000071',now(),now(),repeat('e',64),'OrangeMoney'); raise exception 'WRONG_CHANNEL_DEVICE_ACCEPTED'; exception when insufficient_privilege then null; end;
 v:=public.ns_subscription_ingest_credit('80000000-0000-4000-8000-000000000073','10000000-0000-4000-8000-000000000072','admin-ci','orange_money','ORFIXTURE71','237690000073',i.amount_xaf,'690000071',now(),now(),repeat('e',64),'OrangeMoney');
 if v->>'status' is distinct from 'matched' or not exists(select 1 from public.ns_subscription_intents where id=i.id and status='confirmed' and receipt_number is not null) then raise exception 'ORANGE_PAIRED_PROOF_FAILED'; end if;
end $f$;
-- Entitlement status is derived from dates, not a mutable client flag.
set local role authenticated;
do $f$ declare v jsonb; begin
 v:=public.ns_subscription_access_state('20000000-0000-4000-8000-000000000071');
 if v->>'state' is distinct from 'active' or v->>'paid_access' is distinct from 'true' then raise exception 'PAID_ACCESS_MISSING'; end if;
 begin perform public.ns_subscription_access_state('20000000-0000-4000-8000-000000000001'); raise exception 'CROSS_TENANT_ACCESS_STATE'; exception when insufficient_privilege then null; end;
 if has_function_privilege(current_user,'public.ns_subscription_review_reject(uuid,uuid,text,uuid,text)','EXECUTE') or has_table_privilege(current_user,'public.ns_subscription_review_audit','SELECT') then raise exception 'PAYER_REVIEW_PRIVILEGE'; end if;
end $f$;
reset role;
-- A mismatching credit is held for review and cannot activate or modify a paid period.
set local role authenticated;
do $f$ declare i jsonb; begin
 i:=public.ns_subscription_create('20000000-0000-4000-8000-000000000071','ACCESS',1,'mtn_momo');
 perform public.ns_subscription_declare_sms((i->>'id')::uuid,'Your payment of '||(i->>'amount_xaf')||' XAF to CI ONLY (237690000072) was completed at '||to_char(now() at time zone 'Africa/Douala','YYYY-MM-DD HH24:MI:SS')||'. Financial transaction id: REVIEWTX71','690000071',null);
end $f$;
reset role;
do $f$ declare i public.ns_subscription_intents%rowtype; c public.ns_subscription_credit_candidates%rowtype; v jsonb; v2 jsonb; before_end date; begin
 select period_end_exclusive into before_end from public.ns_subscriptions where org_id='20000000-0000-4000-8000-000000000071';
 select * into i from public.ns_subscription_intents where org_id='20000000-0000-4000-8000-000000000071' and status='submitted';
 v:=public.ns_subscription_ingest_credit('80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci','mtn_momo','REVIEWTX71','237690000072',i.amount_xaf+1,'690000071',now(),now(),repeat('d',64),'MobileMoney');
 if v->>'status' is distinct from 'review' then raise exception 'MISMATCH_NOT_REVIEWED'; end if;
 select * into c from public.ns_subscription_credit_candidates where transaction_reference='REVIEWTX71';
 v:=public.ns_subscription_review_list('80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci');
 if not exists(select 1 from jsonb_array_elements(v) item where item->>'id'=c.id::text and item->>'payer_tail'='0071' and not (item ? 'payer_number')) then raise exception 'REVIEW_LIST_MISSING_OR_UNREDACTED'; end if;
 begin perform public.ns_subscription_review_reject('80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000071','admin-ci',c.id,'wrong_amount'); raise exception 'PAYER_REJECTED'; exception when insufficient_privilege then null; end;
 v:=public.ns_subscription_review_reject('80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci',c.id,'wrong_amount');
 v2:=public.ns_subscription_review_reject('80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci',c.id,'wrong_amount');
 if v->>'status' is distinct from 'rejected' or v<>v2 or (select count(*) from public.ns_subscription_review_audit where candidate_id=c.id)<>1 then raise exception 'REVIEW_AUDIT_FAILED'; end if;
 if (select status from public.ns_subscription_intents where id=i.id)<>'submitted' or (select period_end_exclusive from public.ns_subscriptions where org_id=i.org_id)<>before_end then raise exception 'REVIEW_ALTERED_ACCESS'; end if;
end $f$;
-- Seed an organization-wide catalog row (no site). It must not bypass expiry.
insert into public.ns_loyalty_programs(org_id,activity_profile,program_code,name,metric_code,unit_amount_xaf,target_value,reward_description,created_by,updated_by)
 values('20000000-0000-4000-8000-000000000071','autre','points','CI loyalty','points',100,10,'CI reward','60000000-0000-4000-8000-000000000071','60000000-0000-4000-8000-000000000071');
-- Paid access expires without deleting data; renewal and status remain available.
update public.ns_subscriptions set period_start=(now() at time zone 'Africa/Douala')::date-interval '2 months',period_end_exclusive=(now() at time zone 'Africa/Douala')::date-1 where org_id='20000000-0000-4000-8000-000000000071';
update public.ns_subscription_intents set submitted_at=case when submitted_at is null then null else now()-interval '2 days' end,confirmed_at=case when confirmed_at is null then null else now()-interval '3 days' end where org_id='20000000-0000-4000-8000-000000000071';
set local role authenticated;
do $f$ declare a jsonb; begin
 a:=public.ns_subscription_access_state('20000000-0000-4000-8000-000000000071');
 if a->>'state' is distinct from 'expired' or a->>'erp_access' is distinct from 'false' or a->>'access_reason' is distinct from 'blocked' then raise exception 'EXPIRED_ERP_ACCESS'; end if;
 if public.ns_can_access_site('20000000-0000-4000-8000-000000000071','30000000-0000-4000-8000-000000000071') then raise exception 'EXPIRED_SITE_ACCESS'; end if;
 if exists(select 1 from public.ns_loyalty_programs where org_id='20000000-0000-4000-8000-000000000071') then raise exception 'EXPIRED_ORG_CATALOG_VISIBLE'; end if;
 begin perform public.ns_pull_sync_changes('20000000-0000-4000-8000-000000000071','80000000-0000-4000-8000-000000000071',0,100); raise exception 'EXPIRED_PULL_ALLOWED'; exception when insufficient_privilege then null; end;
 begin perform public.ns_apply_sync_event('20000000-0000-4000-8000-000000000071',null,null,'80000000-0000-4000-8000-000000000071','90000000-0000-4000-8000-000000000071',1,'loyalty_program','fixture','loyalty_program.updated','{"org_id":"20000000-0000-4000-8000-000000000071"}'::jsonb); raise exception 'EXPIRED_PUSH_ALLOWED'; exception when insufficient_privilege then null; end;
 if public.ns_subscription_list('20000000-0000-4000-8000-000000000071')->'intents' is null then raise exception 'BILLING_LOCKED'; end if;
end $f$;
reset role;
-- The current declaration may provide one bounded provisional access window.
update public.ns_subscription_intents set submitted_at=now()-interval '1 hour' where org_id='20000000-0000-4000-8000-000000000071' and status='submitted';
-- A paired credit arriving first can confirm in the same transaction as the debit declaration.
-- Its already-confirmed declaration must not consume the next provisional window.
update public.ns_subscription_intents set submitted_at=confirmed_at where org_id='20000000-0000-4000-8000-000000000071' and status='confirmed';
set local role authenticated;
do $f$ declare a jsonb; begin
 a:=public.ns_subscription_access_state('20000000-0000-4000-8000-000000000071');
 if a->>'paid_access' is distinct from 'false' or a->>'erp_access' is distinct from 'true' or a->>'access_reason' is distinct from 'provisional' then raise exception 'PROVISIONAL_ACCESS_FAILED: %',a; end if;
 if not exists(select 1 from public.ns_loyalty_programs where org_id='20000000-0000-4000-8000-000000000071') then raise exception 'CATALOG_DATA_LOST_OR_NOT_RESTORED'; end if;
end $f$;
reset role;
rollback;
