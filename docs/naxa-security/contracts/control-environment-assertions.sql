begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000291'),('00000000-0000-0000-0000-000000000292');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000291','QA supervision');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000291','00000000-0000-0000-0000-000000000291','manager',true),('10000000-0000-0000-0000-000000000291','00000000-0000-0000-0000-000000000292','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000291','10000000-0000-0000-0000-000000000291','QA'),('20000000-0000-0000-0000-000000000292','10000000-0000-0000-0000-000000000291','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000291','20000000-0000-0000-0000-000000000291','00000000-0000-0000-0000-000000000291',true),('10000000-0000-0000-0000-000000000291','20000000-0000-0000-0000-000000000291','00000000-0000-0000-0000-000000000292',true);
insert into public.sec_devices(id,organization_id,site_id,label,kind) values ('40000000-0000-0000-0000-000000000291','10000000-0000-0000-0000-000000000291','20000000-0000-0000-0000-000000000291','QA sensor','environment'),('40000000-0000-0000-0000-000000000292','10000000-0000-0000-0000-000000000291','20000000-0000-0000-0000-000000000292','Other sensor','environment');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000291',true);
do $q$declare o uuid:='10000000-0000-0000-0000-000000000291';s uuid:='20000000-0000-0000-0000-000000000291';d uuid:='40000000-0000-0000-0000-000000000291';v jsonb;begin
 v:=public.sec_environment_policy(o,s,d,'temperature',35,false);
 if v->'thresholds'->0->>'upper_limit'<>'35' or v->>'physical_action'<>'false' then raise exception 'threshold';end if;
 begin perform public.sec_environment_policy(o,s,d,'humidity',101,false);raise exception 'invalid humidity';exception when invalid_parameter_value then null;end;
 begin perform public.sec_environment_policy(o,s,'40000000-0000-0000-0000-000000000292','temperature',35,false);raise exception 'cross-site sensor';exception when insufficient_privilege then null;end;
 v:=public.sec_control_snapshot(o,s);
 if v->>'devices_total'<>'1' or v->>'devices_stale_or_unknown'<>'1' or v->>'devices_recent'<>'0' then raise exception 'snapshot unknown';end if;
 v:=public.sec_environment_policy(o,s,d,'temperature',null,true);
 if jsonb_array_length(v->'thresholds')<>0 then raise exception 'remove threshold';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000292',true);
do $q$begin
 begin perform public.sec_environment_policy('10000000-0000-0000-0000-000000000291','20000000-0000-0000-0000-000000000291');raise exception 'operator access';exception when insufficient_privilege then null;end;
end $q$;
reset role;rollback;
