-- Disposable database; use only synthetic destination and evidence.
begin;
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000071'),('10000000-0000-4000-8000-000000000072');
insert into public.ns_organizations(id,display_name,business_mode,status) values ('20000000-0000-4000-8000-000000000071','Subscription CI','solo','active');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,status,password_change_required) values ('50000000-0000-4000-8000-000000000071','10000000-0000-4000-8000-000000000071','SUB-CI','sub-ci@example.invalid','active',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code,status) values ('60000000-0000-4000-8000-000000000071','20000000-0000-4000-8000-000000000071','50000000-0000-4000-8000-000000000071','CI payer','promoter','active');
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000071','60000000-0000-4000-8000-000000000071','organization','20000000-0000-4000-8000-000000000071',true,true,true);
insert into public.ns_devices(account_id,installation_id,platform,label,remember_device,session_id) values ('50000000-0000-4000-8000-000000000071','sub-ci','android','CI payer',true,'sub-ci-session');
insert into public.ns_subscription_destinations values ('mtn_momo','123456','CI ONLY','FIXTURE71',true);
insert into public.ns_subscription_admin_devices(id,auth_user_id,channel,session_id,active) values ('80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','mtn_momo','admin-ci',true);
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
 i:=public.ns_subscription_create('20000000-0000-4000-8000-000000000071','ACCESS',1,'mtn_momo');
 if i->>'status'<>'pending' then raise exception 'INVALID_INTENT'; end if;
 j:=public.ns_subscription_declare((i->>'id')::uuid,'FIXTURETX71','690000071',now(),repeat('a',64));
 if j->>'status'<>'submitted' or j->>'receipt_number' is not null then raise exception 'SINGLE_PROOF_CONFIRMED'; end if;
end $f$;
reset role;
do $f$
declare i public.ns_subscription_intents%rowtype; r jsonb; r2 jsonb; begin
 select * into i from public.ns_subscription_intents where org_id='20000000-0000-4000-8000-000000000071';
 if exists(select 1 from public.ns_subscriptions where org_id=i.org_id) then raise exception 'PREMATURE_SUBSCRIPTION'; end if;
 begin
  perform public.ns_subscription_confirm_credit(i.id,'80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci','mtn_momo','FIXTURETX71','FIXTURE71',i.amount_xaf+1,'690000071',now(),now(),repeat('b',64),'MobileMoney');
  raise exception 'WRONG_AMOUNT_ACCEPTED';
 exception when raise_exception then if sqlerrm<>'NS_CREDIT_PROOF_MISMATCH' then raise; end if; end;
 r:=public.ns_subscription_confirm_credit(i.id,'80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci','mtn_momo','FIXTURETX71','FIXTURE71',i.amount_xaf,'690000071',now(),now(),repeat('b',64),'MobileMoney');
 r2:=public.ns_subscription_confirm_credit(i.id,'80000000-0000-4000-8000-000000000072','10000000-0000-4000-8000-000000000072','admin-ci','mtn_momo','FIXTURETX71','FIXTURE71',i.amount_xaf,'690000071',now(),now(),repeat('b',64),'MobileMoney');
 if r->>'status'<>'confirmed' or r->>'receipt_number' is null or r<>r2 or (select count(*) from public.ns_subscription_credit_proofs where intent_id=i.id)<>1 then raise exception 'CONFIRMATION_OR_IDEMPOTENCE_FAILED'; end if;
 if exists(select 1 from public.ns_payments where org_id=i.org_id) then raise exception 'SUBSCRIPTION_LEAKED_INTO_TENANT_CASH'; end if;
end $f$;
rollback;
