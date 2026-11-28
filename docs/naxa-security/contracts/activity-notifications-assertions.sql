begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000221'),('00000000-0000-0000-0000-000000000222'),('00000000-0000-0000-0000-000000000223');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000221','QA notifications');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000221','00000000-0000-0000-0000-000000000221','manager',true),('10000000-0000-0000-0000-000000000221','00000000-0000-0000-0000-000000000222','operator',true),('10000000-0000-0000-0000-000000000221','00000000-0000-0000-0000-000000000223','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000221','10000000-0000-0000-0000-000000000221','QA'),('20000000-0000-0000-0000-000000000222','10000000-0000-0000-0000-000000000221','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000221','20000000-0000-0000-0000-000000000221','00000000-0000-0000-0000-000000000221',true),('10000000-0000-0000-0000-000000000221','20000000-0000-0000-0000-000000000221','00000000-0000-0000-0000-000000000222',true),('10000000-0000-0000-0000-000000000221','20000000-0000-0000-0000-000000000222','00000000-0000-0000-0000-000000000223',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000222',true);
select public.sec_field_action('10000000-0000-0000-0000-000000000221','20000000-0000-0000-0000-000000000221','50000000-0000-0000-0000-000000000221','safety_report',null,'{"reason":"private QA note"}');
select public.sec_field_action('10000000-0000-0000-0000-000000000221','20000000-0000-0000-0000-000000000221','50000000-0000-0000-0000-000000000221','safety_report',null,'{"reason":"private QA note"}');
do $q$begin if (select count(*) from public.sec_activity_notifications)<>0 then raise exception 'wrong recipient';end if;end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000221',true);
do $q$declare n uuid;j jsonb;begin
 if (select count(*) from public.sec_activity_notifications where source='safety' and event_type='reported')<>1 then raise exception 'notification missing or duplicate';end if;
 select id into n from public.sec_activity_notifications;
 j:=public.sec_read_activity('10000000-0000-0000-0000-000000000221','20000000-0000-0000-0000-000000000221',n);
 if j->>'read_at' is null or j<>public.sec_read_activity('10000000-0000-0000-0000-000000000221','20000000-0000-0000-0000-000000000221',n) or j::text like '%private QA note%' then raise exception 'invalid receipt';end if;
 if has_table_privilege(current_user,'public.sec_activity_notifications','INSERT') then raise exception 'client insert';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000223',true);
do $q$begin
 if (select count(*) from public.sec_activity_notifications)<>0 then raise exception 'cross site leak';end if;
 begin perform public.sec_read_activity('10000000-0000-0000-0000-000000000221','20000000-0000-0000-0000-000000000221',gen_random_uuid());raise exception 'cross site ack';exception when insufficient_privilege then null;end;
end $q$;
reset role;rollback;
