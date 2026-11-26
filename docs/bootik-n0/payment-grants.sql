-- Test-only separate merchant reconciliation role.
create role bootik_payment_runtime login password 'bootik-payment-test-only';
grant usage on schema bootik to bootik_payment_runtime;
do $$ declare n text;begin foreach n in array array['bk_payment_destinations','bk_payment_intents','bk_payer_proofs'] loop
 execute format('create policy bk_runtime_access on bootik.%I to bootik_runtime using(true) with check(true)',n);
end loop;
foreach n in array array['bk_payment_intents','bk_payer_proofs','bk_merchant_devices','bk_merchant_proofs','bk_paid_periods'] loop
 execute format('create policy bk_payment_access on bootik.%I to bootik_payment_runtime using(true) with check(true)',n);
end loop;end $$;
grant select on bootik.bk_payment_destinations,bootik.bk_payment_intents,bootik.bk_payer_proofs to bootik_runtime;
grant insert on bootik.bk_payment_intents,bootik.bk_payer_proofs to bootik_runtime;
grant update(state) on bootik.bk_payment_intents to bootik_runtime;
grant execute on function bootik.bk_prepare_subscription(uuid,uuid,uuid,uuid,text,text,int,text,uuid),bootik.bk_submit_debit(uuid,uuid,uuid,uuid,uuid,text,bigint,text,timestamptz,text) to bootik_runtime;
grant select on bootik.bk_payment_intents,bootik.bk_payer_proofs,bootik.bk_merchant_devices,bootik.bk_merchant_proofs,bootik.bk_paid_periods to bootik_payment_runtime;
grant insert on bootik.bk_merchant_proofs,bootik.bk_paid_periods to bootik_payment_runtime;
grant update(state,paid_period_id) on bootik.bk_payment_intents to bootik_payment_runtime;
grant execute on function bootik.bk_capture_credit(text,text,text,bigint,text,timestamptz,text),bootik.bk_reconcile_subscription(uuid),bootik.bk_confirm_paid_period(uuid,uuid,text,text,int,bigint,text),bootik.bk_quote(text,text,int) to bootik_payment_runtime;
