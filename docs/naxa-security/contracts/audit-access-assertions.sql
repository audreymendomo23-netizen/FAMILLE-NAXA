begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000261'),('00000000-0000-0000-0000-000000000262'),('00000000-0000-0000-0000-000000000263');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000261','QA access audit');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000261','00000000-0000-0000-0000-000000000261','owner',true),('10000000-0000-0000-0000-000000000261','00000000-0000-0000-0000-000000000262','operator',true),('10000000-0000-0000-0000-000000000261','00000000-0000-0000-0000-000000000263','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000261','10000000-0000-0000-0000-000000000261','QA'),('20000000-0000-0000-0000-000000000262','10000000-0000-0000-0000-000000000261','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000261','00000000-0000-0000-0000-000000000261',true),('10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000261','00000000-0000-0000-0000-000000000262',true),('10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000262','00000000-0000-0000-0000-000000000263',true);
insert into public.sec_evidence_files(id,organization_id,site_id,owner_id,reference,digest,size_bytes) values ('40000000-0000-0000-0000-000000000261','10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000261','00000000-0000-0000-0000-000000000262','qa-private','ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',3);
insert into sec_private.evidence_content values ('40000000-0000-0000-0000-000000000261',decode('YWJj','base64'));
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000261',true);
do $q$declare j jsonb;begin
 if jsonb_array_length(public.sec_site_members('10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000261'))<>3 then raise exception 'members';end if;
 perform public.sec_integration_list('10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000261');
 if public.sec_evidence_download('10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000261','40000000-0000-0000-0000-000000000261') is not null then raise exception 'owner accessed personal file';end if;
 j:=public.sec_audit_page('10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000261','access',null);
 if jsonb_array_length(j->'rows')<>2 then raise exception 'access journal';end if;
 if has_table_privilege(current_user,'public.sec_access_audit','INSERT') or has_table_privilege(current_user,'public.sec_access_audit','UPDATE') or has_table_privilege(current_user,'public.sec_access_audit','DELETE') then raise exception 'audit writable';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000262',true);
do $q$declare j jsonb;begin
 if public.sec_evidence_download('10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000261','40000000-0000-0000-0000-000000000261')->>'base64' is distinct from 'YWJj' then raise exception 'file download';end if;
 j:=public.sec_audit_page('10000000-0000-0000-0000-000000000261','20000000-0000-0000-0000-000000000261','access',null);
 if jsonb_array_length(j->'rows')<>1 or j->'rows'->0->>'operation'<>'evidence_download' or j->'rows'->0->>'object_id'<>'40000000-0000-0000-0000-000000000261' or j->'rows'->0->>'origin'<>'access_rpc' or j::text like '%YWJj%' or j::text like '%qa-private%' then raise exception 'access privacy or metadata';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000263',true);
do $q$begin if exists(select 1 from public.sec_access_audit) then raise exception 'cross site access audit';end if;end $q$;
reset role;rollback;
