-- ZIPPLE N1: same rollback-only SQL recipe as NAXA Services, no Auth password or real session.
begin;
insert into auth.users(id) values ('76100000-0000-4000-8000-000000000001'),('76100000-0000-4000-8000-000000000002'),('76100000-0000-4000-8000-000000000003');
insert into public.zp_organizations(id,name) values ('76200000-0000-4000-8000-000000000001','QA ZIPPLE A'),('76200000-0000-4000-8000-000000000002','QA ZIPPLE B');
insert into public.zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values
('76300000-0000-4000-8000-000000000001','76200000-0000-4000-8000-000000000001','76100000-0000-4000-8000-000000000001','qa-zipple-rollback-a','qa-zipple-rollback-a@example.invalid','staff'),
('76300000-0000-4000-8000-000000000002','76200000-0000-4000-8000-000000000002','76100000-0000-4000-8000-000000000002','qa-zipple-rollback-b','qa-zipple-rollback-b@example.invalid','promoteur');
insert into public.zp_sites(id,org_id,name) values ('76400000-0000-4000-8000-000000000001','76200000-0000-4000-8000-000000000001','QA A'),('76400000-0000-4000-8000-000000000002','76200000-0000-4000-8000-000000000001','QA A2'),('76400000-0000-4000-8000-000000000003','76200000-0000-4000-8000-000000000002','QA B');
insert into public.zp_site_scopes values ('76300000-0000-4000-8000-000000000001','76200000-0000-4000-8000-000000000001','76400000-0000-4000-8000-000000000001'),('76300000-0000-4000-8000-000000000002','76200000-0000-4000-8000-000000000002','76400000-0000-4000-8000-000000000003');
insert into public.zp_recovery_operators(auth_user_id) values ('76100000-0000-4000-8000-000000000003');
-- Test actual role grants, not merely catalog metadata.
set local role anon;
do $qa$ begin
 begin perform 1 from public.zp_members; raise exception 'ANON_READ_ACCEPTED'; exception when insufficient_privilege then null; end;
 begin perform public.zp_identity('76300000-0000-4000-8000-000000000001'); raise exception 'ANON_RPC_ACCEPTED'; exception when insufficient_privilege then null; end;
end $qa$;
reset role;
set local role authenticated;
do $qa$ begin
 begin perform 1 from public.zp_members; raise exception 'CLIENT_READ_ACCEPTED'; exception when insufficient_privilege then null; end;
 begin perform public.zp_identity('76300000-0000-4000-8000-000000000001'); raise exception 'CLIENT_RPC_ACCEPTED'; exception when insufficient_privilege then null; end;
end $qa$;
reset role;
set local role service_role;
do $qa$
declare
 m uuid:='76300000-0000-4000-8000-000000000001'; m2 uuid:='76300000-0000-4000-8000-000000000002';
 u uuid:='76100000-0000-4000-8000-000000000001'; u2 uuid:='76100000-0000-4000-8000-000000000002'; op uuid:='76100000-0000-4000-8000-000000000003';
 o uuid:='76200000-0000-4000-8000-000000000001'; o2 uuid:='76200000-0000-4000-8000-000000000002';
 s uuid:='76400000-0000-4000-8000-000000000001'; s2 uuid:='76400000-0000-4000-8000-000000000002'; s3 uuid:='76400000-0000-4000-8000-000000000003';
 a text:='qa-rollback-hash-a'; f text:='qa-rollback-hash-f'; a2 text:='qa-rollback-hash-a2'; f2 text:='qa-rollback-hash-f2'; a3 text:='qa-rollback-hash-a3'; f3 text:='qa-rollback-hash-f3'; rid uuid; attempt uuid:='76500000-0000-4000-8000-000000000001'; retry uuid:='76500000-0000-4000-8000-000000000002'; ident jsonb;
begin
 ident:=public.zp_issue(m,u,0,a,f);
 if ident->>'app_id' is distinct from 'ZIPPLE' or ident->>'role' is distinct from 'staff' or ident->>'organization_id' is distinct from o::text or jsonb_array_length(ident->'active_sites') is distinct from 1 or ident->'active_sites'->0->>'id' is distinct from s::text then raise exception 'SCOPE_WRONG'; end if;
 begin perform public.zp_issue(m,u2,0,'qa-invalid-a',null); raise exception 'FOREIGN_AUTH_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 if public.zp_probe_receipt(a,o,m,s,'qa-replay','digest-a') is distinct from 'acknowledged' then raise exception 'PROBE_FAILED'; end if;
 if public.zp_probe_receipt(a,o,m,s,'qa-replay','digest-a') is distinct from 'acknowledged' then raise exception 'REPLAY_FAILED'; end if;
 if public.zp_probe_receipt(a,o,m,s,'qa-replay','digest-b') is distinct from 'conflict' then raise exception 'CONFLICT_FAILED'; end if;
 if (select count(*) from public.zp_n1_receipts where member_id=m and event_id='qa-replay')<>1 then raise exception 'DUPLICATE_RECEIPT'; end if;
 begin perform public.zp_probe_receipt(a,o,m,s2,'qa-denied','digest-a'); raise exception 'UNASSIGNED_SITE_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 begin perform public.zp_probe_receipt(a,o2,m2,s3,'qa-denied','digest-a'); raise exception 'FOREIGN_ORG_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 begin insert into public.zp_site_scopes values(m,o,s3); raise exception 'CROSS_SCOPE_ACCEPTED'; exception when foreign_key_violation then null; end;
 perform public.zp_rotate(f,a2,f2);
 begin perform public.zp_rotate(f,'qa-invalid-a','qa-invalid-f'); raise exception 'OLD_REFRESH_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 begin perform public.zp_probe_receipt(a,o,m,s,'qa-replay','digest-a'); raise exception 'OLD_ACCESS_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 if public.zp_probe_receipt(a2,o,m,s,'qa-replay','digest-a') is distinct from 'acknowledged' then raise exception 'ROTATED_ACCESS_FAILED'; end if;
 if public.zp_revoke(a2) is distinct from true then raise exception 'REVOKE_FAILED'; end if;
 begin perform public.zp_rotate(f2,'qa-invalid-a','qa-invalid-f'); raise exception 'REVOKED_REFRESH_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 begin perform public.zp_probe_receipt(a2,o,m,s,'qa-replay','digest-a'); raise exception 'REVOKED_ACCESS_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 perform public.zp_issue(m,u,0,a3,f3);
 perform public.zp_recovery('qa-zipple-rollback-a'); perform public.zp_recovery('qa-zipple-rollback-unknown');
 select id into strict rid from public.zp_recovery_requests where member_id=m;
 begin perform public.zp_admin_recovery_list(u2); raise exception 'NON_OPERATOR_LIST_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 if not exists(select 1 from jsonb_array_elements(public.zp_admin_recovery_list(op)) x where x->>'id'=rid::text) then raise exception 'OPERATOR_LIST_FAILED'; end if;
 begin perform public.zp_admin_recovery_begin(u2,rid,'QA identity checked',attempt); raise exception 'NON_OPERATOR_RESET_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 if public.zp_admin_recovery_begin(op,rid,'QA identity checked',attempt) is distinct from u then raise exception 'RESET_TARGET_WRONG'; end if;
 begin perform public.zp_probe_receipt(a3,o,m,s,'qa-replay','digest-a'); raise exception 'RESET_OLD_SESSION_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 if public.zp_admin_recovery_finish(op,rid,attempt,false) is distinct from true then raise exception 'FAILURE_NOT_RECORDED'; end if;
 if (select reset_pending from public.zp_members where id=m) is distinct from true then raise exception 'FAILED_RESET_UNLOCKED'; end if;
 begin perform public.zp_issue(m,u,0,'qa-invalid-a',null); raise exception 'LOCKED_ACCOUNT_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 perform public.zp_admin_recovery_begin(op,rid,'QA retry checked',retry);
 begin perform public.zp_admin_recovery_finish(op,rid,attempt,true); raise exception 'STALE_ATTEMPT_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 if public.zp_admin_recovery_finish(op,rid,retry,true) is distinct from true then raise exception 'RETRY_FAILED'; end if;
 if (select reset_pending or credential_epoch<>2 from public.zp_members where id=m) is distinct from false then raise exception 'EPOCH_WRONG'; end if;
 if (select count(*) from public.zp_recovery_audit where request_id=rid)<>4 then raise exception 'AUDIT_WRONG'; end if;
 begin perform public.zp_issue(m,u,0,'qa-invalid-a',null); raise exception 'STALE_EPOCH_ACCEPTED'; exception when raise_exception then if sqlerrm<>'DENIED' then raise; end if; end;
 perform public.zp_issue(m,u,2,'qa-post-reset-a',null);
end $qa$;
reset role;
rollback;
select 'ZIPPLE_N1_HOSTED_SQL_ROLLBACK_PASS' as result;
