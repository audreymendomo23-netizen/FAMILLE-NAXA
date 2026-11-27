-- Run after candidate schema on disposable PostgreSQL only.
begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000001','QA A'),('10000000-0000-0000-0000-000000000002','QA B');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','operator',true),('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','QA A1'),('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','QA A2'),('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','QA B1');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',true);
insert into public.sec_devices(organization_id,site_id,label,kind) select organization_id,id,name,'camera' from public.sec_sites;
insert into public.sec_incidents(organization_id,site_id,subject,priority,state) select organization_id,id,'QA only','P2','new' from public.sec_sites;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $$begin
 if (select count(*) from public.sec_organizations)<>1 then raise exception 'org isolation';end if;
 if (select count(*) from public.sec_sites)<>1 then raise exception 'site isolation';end if;
 if (select count(*) from public.sec_devices)<>1 then raise exception 'device isolation';end if;
 if (select count(*) from public.sec_incidents)<>1 then raise exception 'incident isolation';end if;
 if has_table_privilege(current_user,'public.sec_devices','INSERT') then raise exception 'unexpected client write';end if;
end$$;
reset role;
update public.sec_memberships set active=false where user_id='00000000-0000-0000-0000-000000000001';
set local role authenticated;
do $$begin if (select count(*) from public.sec_devices)<>0 then raise exception 'revocation';end if;end$$;
reset role;
set local role anon;
do $$begin if has_table_privilege(current_user,'public.sec_devices','SELECT') then raise exception 'anonymous access';end if;end$$;
reset role;
rollback;
