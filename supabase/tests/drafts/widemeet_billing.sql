-- Test-only ledger and verified receipt fixtures; no provider or transfer.
begin;
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000061'),('00000000-0000-4000-8000-000000000062');
insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values
('10000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000061','WM-BILLING01','wm-bill-owner@example.invalid','Owner'),
('10000000-0000-4000-8000-000000000062','00000000-0000-4000-8000-000000000062','WM-BILLING02','wm-bill-staff@example.invalid','Staff');
insert into public.wm_workspaces(id,kind,name) values
('20000000-0000-4000-8000-000000000061','enterprise','Billing enterprise'),
('20000000-0000-4000-8000-000000000062','individual','Billing individual');
insert into public.wm_memberships(account_id,workspace_id,role) values
('10000000-0000-4000-8000-000000000061','20000000-0000-4000-8000-000000000061','promoteur'),
('10000000-0000-4000-8000-000000000062','20000000-0000-4000-8000-000000000061','staff'),
('10000000-0000-4000-8000-000000000062','20000000-0000-4000-8000-000000000062','owner');
do $wm$ begin
 if has_function_privilege('authenticated','public.wm_settle_verified_receipt(uuid,text,text,integer,text,text,timestamptz)','EXECUTE') or has_table_privilege('anon','public.wm_billing_intents','SELECT') then raise exception 'billing ACL leak';end if;
end $wm$;
set local role service_role;
do $wm$ declare
 a text:=repeat('a',64); b text:=repeat('b',64); c text:=repeat('c',64);
 w uuid:='20000000-0000-4000-8000-000000000061'; z uuid:='20000000-0000-4000-8000-000000000062';
 d jsonb; r jsonb; id uuid; pid uuid; deadline timestamptz; t timestamptz:=clock_timestamp();
begin
 perform public.wm_issue_verified_session('10000000-0000-4000-8000-000000000061','30000000-0000-4000-8000-000000000061',w,a,0);
 perform public.wm_issue_verified_session('10000000-0000-4000-8000-000000000062','30000000-0000-4000-8000-000000000062',w,b,0);
 perform public.wm_issue_verified_session('10000000-0000-4000-8000-000000000062','30000000-0000-4000-8000-000000000063',z,c,0);
 if public.wm_quote('enterprise','access','year',20) is distinct from 50000 or public.wm_quote('enterprise','premium','year',50) is distinct from 100000 or public.wm_quote('individual','pass','once',20) is distinct from 1000 or public.wm_quote('individual','pass','once',100) is distinct from 5000 or public.wm_quote('enterprise','premium','month',100) is not null then raise exception 'quote mismatch';end if;
 d:=jsonb_build_object('request_id',gen_random_uuid(),'offer','access','period','month','capacity',20,'channel','OM');
 if public.wm_billing_action(b,'billing-create',d) is not null then raise exception 'staff purchase accepted';end if;
 r:=public.wm_billing_action(a,'billing-create',d);id:=(r->>'id')::uuid;
 if id is null or (r->>'amount')::integer is distinct from 5000 or r->>'status' is distinct from 'pending' then raise exception 'intent creation failed';end if;
 if public.wm_billing_action(a,'billing-create',d) is distinct from r then raise exception 'intent replay not stable';end if;
 if public.wm_billing_action(a,'billing-create',jsonb_set(d,'{channel}','"MOMO"')) is not null then raise exception 'changed intent accepted';end if;
 if exists(select 1 from public.wm_room_entitlements where workspace_id=w) then raise exception 'pending intent activated entitlement';end if;
 if public.wm_billing_action(c,'billing-cancel',jsonb_build_object('id',id)) is not null then raise exception 'cross workspace cancellation';end if;
 if public.wm_settle_verified_receipt(id,'OM','fixture-receipt-1',4999,'XAF',repeat('d',64),t) or public.wm_settle_verified_receipt(id,'MOMO','fixture-receipt-1',5000,'XAF',repeat('d',64),t) then raise exception 'invalid receipt accepted';end if;
 if not public.wm_settle_verified_receipt(id,'OM','fixture-receipt-1',5000,'XAF',repeat('d',64),t) then raise exception 'fixture receipt settlement failed';end if;
 select valid_until into deadline from public.wm_room_entitlements where workspace_id=w and plan='access' and enabled;
 if deadline is null then raise exception 'entitlement not activated';end if;
 if not public.wm_settle_verified_receipt(id,'OM','fixture-receipt-1',5000,'XAF',repeat('d',64),t) then raise exception 'settlement retry failed';end if;
 if (select valid_until from public.wm_room_entitlements where workspace_id=w) is distinct from deadline then raise exception 'double extension';end if;
 if public.wm_billing_action(a,'billing-cancel',jsonb_build_object('id',id)) is not null then raise exception 'confirmed cancellation';end if;
 d:=jsonb_build_object('request_id',gen_random_uuid(),'offer','pass','period','once','capacity',50,'channel','MOMO');
 r:=public.wm_billing_action(c,'billing-create',d);pid:=(r->>'id')::uuid;
 if pid is null or (r->>'amount')::integer is distinct from 3000 then raise exception 'pass quote failed';end if;
 if not public.wm_settle_verified_receipt(pid,'MOMO','fixture-receipt-2',3000,'XAF',repeat('e',64),t) then raise exception 'pass settlement failed';end if;
 if not exists(select 1 from public.wm_paid_passes where intent_id=pid and consumed_at is null and valid_until is null) or exists(select 1 from public.wm_room_entitlements where workspace_id=z) then raise exception 'unconsumed pass granted unrestricted access';end if;
end $wm$;
reset role;
rollback;
select 'WIDEMEET_BILLING_SQL_PASS';
