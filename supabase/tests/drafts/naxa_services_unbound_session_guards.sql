-- Read-only assertions under a synthetic, unbound identity. No Auth user created.
-- Run only on the dedicated FAMILLE-NAXA integration database or disposable CI.
begin;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000099',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000099","session_id":"qa-unbound","role":"authenticated"}',true);
set local role authenticated;
do $test$
declare o uuid:='20000000-0000-4000-8000-000000000099'; s uuid:='30000000-0000-4000-8000-000000000099'; d uuid:='40000000-0000-4000-8000-000000000099'; e uuid:='50000000-0000-4000-8000-000000000099';
begin
 if public.ns_current_account_id() is not null or public.ns_current_member_id(o) is not null or public.ns_is_org_member(o) is distinct from false then raise exception 'IDENTITY_GUARD'; end if;
 if public.ns_can_access_site(o,s) is distinct from false or public.ns_can_operate_site(o,s) is distinct from false or public.ns_can_manage_site(o,s) is distinct from false or public.ns_can_manage_org(o) is distinct from false or public.ns_can_manage_member(e) is distinct from false then raise exception 'SITE_GUARD'; end if;
 if public.ns_can_access_workstation(o,s,d) is distinct from false or public.ns_can_operate_workstation(o,s,d) is distinct from false or public.ns_can_access_cash_register(o,s,d,true) is distinct from false or public.ns_can_access_payment(o,s,d,e,true) is distinct from false or public.ns_can_access_pressing_order(o,s,d,true) is distinct from false then raise exception 'WORKSTATION_GUARD'; end if;
 if public.ns_erp_access_reason(o) is distinct from 'blocked' then raise exception 'ERP_GUARD'; end if;
 begin perform public.ns_create_performance_objective(o,s,'daily',current_date,current_date,100,'QA'); raise exception 'UNAUTHORIZED_OBJECTIVE'; exception when raise_exception then if sqlerrm<>'NAXA_OBJECTIVE_FORBIDDEN' then raise; end if; end;
 begin perform public.ns_apply_sync_event(o,s,null,d,e,1,'sale','QA','sale.created',jsonb_build_object('org_id',o)); raise exception 'UNAUTHORIZED_SYNC_WRITE'; exception when raise_exception then if sqlerrm<>'NAXA_SYNC_AUTH_REQUIRED' then raise; end if; end;
 begin perform public.ns_pull_sync_changes(o,d,0,1); raise exception 'UNAUTHORIZED_SYNC_READ'; exception when raise_exception then if sqlerrm<>'NAXA_SYNC_AUTH_REQUIRED' then raise; end if; end;
 begin perform public.ns_subscription_access_state(o); raise exception 'UNAUTHORIZED_SUB_ACCESS'; exception when insufficient_privilege then null; end;
 begin perform public.ns_subscription_list(o); raise exception 'UNAUTHORIZED_SUB_LIST'; exception when insufficient_privilege then null; end;
 begin perform public.ns_subscription_create(o,'ACCESS',1,'mtn_momo'); raise exception 'UNAUTHORIZED_SUB_CREATE'; exception when insufficient_privilege then null; end;
 begin perform public.ns_subscription_cancel(e,true); raise exception 'UNAUTHORIZED_SUB_CANCEL'; exception when insufficient_privilege then null; end;
 begin perform public.ns_subscription_declare_sms(e,'synthetic QA only','000000000',now()); raise exception 'UNAUTHORIZED_SUB_DECLARE'; exception when insufficient_privilege then null; end;
end $test$;
reset role;
rollback;
select 'PASS: 22 callable SECURITY DEFINER functions reject unbound authenticated identity' as result;
