begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000161'),('00000000-0000-0000-0000-000000000162'),('00000000-0000-0000-0000-000000000163');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000161','QA ERP');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000161','00000000-0000-0000-0000-000000000161','manager',true),('10000000-0000-0000-0000-000000000161','00000000-0000-0000-0000-000000000162','operator',true),('10000000-0000-0000-0000-000000000161','00000000-0000-0000-0000-000000000163','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000161','10000000-0000-0000-0000-000000000161','QA'),('20000000-0000-0000-0000-000000000162','10000000-0000-0000-0000-000000000161','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','00000000-0000-0000-0000-000000000161',true),('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','00000000-0000-0000-0000-000000000162',true),('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000162','00000000-0000-0000-0000-000000000163',true);
insert into public.sec_devices(id,organization_id,site_id,label,kind) values ('40000000-0000-0000-0000-000000000161','10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','QA sensor','environment');
insert into public.sec_work_orders(id,organization_id,site_id,subject,kind,reporter_id,request_id) values ('40000000-0000-0000-0000-000000000162','10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','QA work','inspection','00000000-0000-0000-0000-000000000162',gen_random_uuid());
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000161',true);
do $q$declare j jsonb;begin
 j:=public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000161','shift_create',null,jsonb_build_object('agent_id','00000000-0000-0000-0000-000000000162','label','QA shift','starts_at',now()+interval '1 hour','ends_at',now()+interval '3 hours'));
 if j->>'state'<>'planned' or public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000161','shift_create',null,jsonb_build_object('agent_id','00000000-0000-0000-0000-000000000162','label','QA shift','starts_at',now()+interval '1 hour','ends_at',now()+interval '3 hours'))<>j then raise exception 'shift receipt';end if;
 begin perform public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000162','shift_create',null,jsonb_build_object('agent_id','00000000-0000-0000-0000-000000000162','label','QA shift','starts_at',now()+interval '1 hour','ends_at',now()+interval '3 hours'));raise exception 'overlap accepted';exception when unique_violation then null;end;
 begin perform public.sec_field_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000180','work','40000000-0000-0000-0000-000000000162','{"reason":"legacy bypass","next":"assigned"}');raise exception 'assignment bypass';exception when invalid_parameter_value then null;end;
 perform public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000163','maintenance_assign','40000000-0000-0000-0000-000000000162',jsonb_build_object('device_id','40000000-0000-0000-0000-000000000161','technician_id','00000000-0000-0000-0000-000000000162','scheduled_at',now()));
 begin perform public.sec_field_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000181','work','40000000-0000-0000-0000-000000000162','{"reason":"legacy bypass","next":"in_progress"}');raise exception 'technician bypass';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000162',true);
select public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000164','shift_accept','50000000-0000-0000-0000-000000000161','{}');
select public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000165','maintenance_start','40000000-0000-0000-0000-000000000162','{}');
select public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000166','maintenance_complete','40000000-0000-0000-0000-000000000162','{"diagnosis":"QA inspection","cost_fcfa":2500}');
do $q$begin
 if (select completed_at from public.sec_maintenance_details where order_id='40000000-0000-0000-0000-000000000162') is null then raise exception 'completion missing';end if;
 begin perform public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000167','maintenance_review','40000000-0000-0000-0000-000000000162','{}');raise exception 'self review';exception when insufficient_privilege then null;end;
 begin perform public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000168','shift_complete','50000000-0000-0000-0000-000000000161','{}');raise exception 'early completion';exception when invalid_parameter_value then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000161',true);
do $q$begin
 begin perform public.sec_field_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000169','work','40000000-0000-0000-0000-000000000162','{"reason":"bypass","next":"completed"}');raise exception 'review bypass';exception when invalid_parameter_value then null;end;
 perform public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000170','maintenance_review','40000000-0000-0000-0000-000000000162','{}');
 if (select state from public.sec_work_orders where id='40000000-0000-0000-0000-000000000162')<>'completed' or (select cost_fcfa from public.sec_maintenance_details where order_id='40000000-0000-0000-0000-000000000162')<>2500 then raise exception 'completion incorrect';end if;
 perform public.sec_erp_action('10000000-0000-0000-0000-000000000161','20000000-0000-0000-0000-000000000161','50000000-0000-0000-0000-000000000171','shift_cancel','50000000-0000-0000-0000-000000000161','{}');
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000163',true);
do $q$begin if (select count(*) from public.sec_shifts)<>0 or (select count(*) from public.sec_maintenance_details)<>0 or (select count(*) from public.sec_erp_events)<>0 then raise exception 'cross site leak';end if;end $q$;
reset role;rollback;
