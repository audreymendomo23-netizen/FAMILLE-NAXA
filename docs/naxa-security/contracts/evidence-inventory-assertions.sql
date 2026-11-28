begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000401'),('00000000-0000-0000-0000-000000000402');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000401','QA integrity');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000401','operator',true),('10000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000402','owner',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000401','10000000-0000-0000-0000-000000000401','QA');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000401','20000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000401',true),('10000000-0000-0000-0000-000000000401','20000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000402',true);
insert into public.sec_evidence_files(id,organization_id,site_id,owner_id,reference,digest,size_bytes) values
('40000000-0000-0000-0000-000000000401','10000000-0000-0000-0000-000000000401','20000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000401','valid','ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',3),
('40000000-0000-0000-0000-000000000402','10000000-0000-0000-0000-000000000401','20000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000401','corrupted','ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',3);
insert into sec_private.evidence_content values ('40000000-0000-0000-0000-000000000401',decode('YWJj','base64')),('40000000-0000-0000-0000-000000000402',decode('eHl6','base64'));
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000401',true);
do $q$declare v jsonb;begin
 v:=public.sec_evidence_inventory('10000000-0000-0000-0000-000000000401','20000000-0000-0000-0000-000000000401');
 if v->>'total_files'<>'2' or v->>'total_bytes'<>'6' or v::text like '%base64%' then raise exception 'inventory';end if;
 v:=public.sec_evidence_inventory('10000000-0000-0000-0000-000000000401','20000000-0000-0000-0000-000000000401',null,null,'40000000-0000-0000-0000-000000000401');
 if v->'verification'->>'digest_matches'<>'true' or v->'verification'->>'size_matches'<>'true' then raise exception 'valid integrity';end if;
 v:=public.sec_evidence_inventory('10000000-0000-0000-0000-000000000401','20000000-0000-0000-0000-000000000401',null,null,'40000000-0000-0000-0000-000000000402');
 if v->'verification'->>'digest_matches'<>'false' or v->'verification'->>'size_matches'<>'true' then raise exception 'corruption undetected';end if;
 if (select count(*) from public.sec_access_audit where operation='evidence_integrity_check')<>2 then raise exception 'audit missing';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000402',true);
do $q$declare v jsonb;begin
 v:=public.sec_evidence_inventory('10000000-0000-0000-0000-000000000401','20000000-0000-0000-0000-000000000401');
 if v->>'total_files'<>'0' then raise exception 'owner read private inventory';end if;
 v:=public.sec_evidence_inventory('10000000-0000-0000-0000-000000000401','20000000-0000-0000-0000-000000000401',null,null,'40000000-0000-0000-0000-000000000401');
 if v->>'denied'<>'true' or v->'verification'<>'null'::jsonb then raise exception 'private file leak';end if;
 if not exists(select 1 from public.sec_access_audit where operation='evidence_integrity_check' and outcome='denied' and object_id is null) then raise exception 'denial trace';end if;
end $q$;
reset role;rollback;
