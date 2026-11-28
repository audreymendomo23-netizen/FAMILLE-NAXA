begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000311'),('00000000-0000-0000-0000-000000000312');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000311','QA alarm');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000311','00000000-0000-0000-0000-000000000311','manager',true),('10000000-0000-0000-0000-000000000311','00000000-0000-0000-0000-000000000312','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000311','10000000-0000-0000-0000-000000000311','QA'),('20000000-0000-0000-0000-000000000312','10000000-0000-0000-0000-000000000311','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000311','20000000-0000-0000-0000-000000000311','00000000-0000-0000-0000-000000000311',true),('10000000-0000-0000-0000-000000000311','20000000-0000-0000-0000-000000000311','00000000-0000-0000-0000-000000000312',true);
insert into public.sec_devices(id,organization_id,site_id,label,kind) values ('40000000-0000-0000-0000-000000000311','10000000-0000-0000-0000-000000000311','20000000-0000-0000-0000-000000000311','QA gateway','gateway'),('40000000-0000-0000-0000-000000000312','10000000-0000-0000-0000-000000000311','20000000-0000-0000-0000-000000000311','QA access','access');
insert into sec_private.gateway_bindings values ('40000000-0000-0000-0000-000000000311','10000000-0000-0000-0000-000000000311','20000000-0000-0000-0000-000000000311','40000000-0000-0000-0000-000000000312',true);
set local role sec_gateway_ingest;
do $q$declare g uuid:='40000000-0000-0000-0000-000000000311';d uuid:='40000000-0000-0000-0000-000000000312';o uuid:='10000000-0000-0000-0000-000000000311';s uuid:='20000000-0000-0000-0000-000000000311';e uuid:='50000000-0000-0000-0000-000000000311';v jsonb;begin
 v:=sec_private.ingest_alarm(g,o,s,d,e,now(),'intrusion');
 if v<>sec_private.ingest_alarm(g,o,s,d,e,now(),'intrusion') or v->>'physical_action'<>'false' then raise exception 'receipt';end if;
 begin perform sec_private.ingest_alarm(g,o,s,d,e,now(),'sabotage');raise exception 'event conflict accepted';exception when unique_violation then null;end;
end $q$;
reset role;set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000312',true);
do $q$declare o uuid:='10000000-0000-0000-0000-000000000311';s uuid:='20000000-0000-0000-0000-000000000311';a uuid:='50000000-0000-0000-0000-000000000311';v jsonb;begin
 if has_function_privilege(current_user,'sec_private.ingest_alarm(uuid,uuid,uuid,uuid,uuid,timestamptz,text)','EXECUTE') then raise exception 'untrusted ingest';end if;
 v:=public.sec_alarm_action(o,s,gen_random_uuid(),a,'ack','QA acknowledgement');if v->>'triage_state'<>'acknowledged' then raise exception 'ack';end if;
 begin perform public.sec_alarm_action(o,s,gen_random_uuid(),a,'escalate','QA');raise exception 'operator escalation';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000311',true);
do $q$declare o uuid:='10000000-0000-0000-0000-000000000311';s uuid:='20000000-0000-0000-0000-000000000311';a uuid:='50000000-0000-0000-0000-000000000311';e uuid:=gen_random_uuid();v jsonb;begin
 v:=public.sec_alarm_action(o,s,e,a,'escalate','QA escalation');if v<>public.sec_alarm_action(o,s,e,a,'escalate','QA escalation') then raise exception 'duplicate';end if;
 v:=public.sec_alarm_action(o,s,gen_random_uuid(),a,'review','QA internal review');
 if v->>'source_state'<>'intrusion' or v->>'triage_state'<>'reviewed' or v->>'physical_action'<>'false' then raise exception 'physical state changed';end if;
 if (select count(*) from public.sec_activity_notifications where source='alarm')<>2 then raise exception 'notifications';end if;
 if (select count(*) from public.sec_alarm_reviews)<>3 then raise exception 'review log';end if;
 begin perform public.sec_alarm_action(o,'20000000-0000-0000-0000-000000000312',gen_random_uuid(),a,'ack','QA');raise exception 'cross site';exception when insufficient_privilege then null;end;
end $q$;
reset role;rollback;
