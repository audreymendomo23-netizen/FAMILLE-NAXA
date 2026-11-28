begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000321'),('00000000-0000-0000-0000-000000000322'),('00000000-0000-0000-0000-000000000323');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000321','QA share');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000321','00000000-0000-0000-0000-000000000321','operator',true),('10000000-0000-0000-0000-000000000321','00000000-0000-0000-0000-000000000322','operator',true),('10000000-0000-0000-0000-000000000321','00000000-0000-0000-0000-000000000323','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000321','10000000-0000-0000-0000-000000000321','QA');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000321','20000000-0000-0000-0000-000000000321','00000000-0000-0000-0000-000000000321',true),('10000000-0000-0000-0000-000000000321','20000000-0000-0000-0000-000000000321','00000000-0000-0000-0000-000000000322',true),('10000000-0000-0000-0000-000000000321','20000000-0000-0000-0000-000000000321','00000000-0000-0000-0000-000000000323',true);
insert into public.sec_evidence_files(id,organization_id,site_id,owner_id,reference,digest,size_bytes) values ('40000000-0000-0000-0000-000000000321','10000000-0000-0000-0000-000000000321','20000000-0000-0000-0000-000000000321','00000000-0000-0000-0000-000000000321','qa-share','ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',3);
insert into sec_private.evidence_content values ('40000000-0000-0000-0000-000000000321',decode('YWJj','base64'));
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000321',true);
do $q$declare o uuid:='10000000-0000-0000-0000-000000000321';s uuid:='20000000-0000-0000-0000-000000000321';e uuid:='40000000-0000-0000-0000-000000000321';r uuid:='00000000-0000-0000-0000-000000000322';i uuid:='50000000-0000-0000-0000-000000000321';v jsonb;begin
 v:=public.sec_evidence_share(o,s,'create',i,e,r,60);
 if v<>public.sec_evidence_share(o,s,'create',i,e,r,60) then raise exception 'idempotency';end if;
 if has_table_privilege(current_user,'sec_private.evidence_shares','SELECT') then raise exception 'private share leak';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000323',true);
do $q$begin
 begin perform public.sec_evidence_share_download('10000000-0000-0000-0000-000000000321','20000000-0000-0000-0000-000000000321','50000000-0000-0000-0000-000000000321');raise exception 'manager read unauthorized';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000322',true);
do $q$declare o uuid:='10000000-0000-0000-0000-000000000321';s uuid:='20000000-0000-0000-0000-000000000321';i uuid:='50000000-0000-0000-0000-000000000321';v jsonb;begin
 v:=public.sec_evidence_share(o,s,'list');if jsonb_array_length(v->'result'->'shares')<>1 then raise exception 'recipient share missing';end if;
 v:=public.sec_evidence_share_download(o,s,i);if v->>'base64'<>'YWJj' or v->>'share_id'<>i::text then raise exception 'download integrity';end if;
 if not exists(select 1 from public.sec_access_audit where operation='evidence_share_download' and object_id=i) then raise exception 'trace missing';end if;
 begin perform public.sec_evidence_share(o,s,'revoke',i);raise exception 'recipient revoked';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000321',true);
select public.sec_evidence_share('10000000-0000-0000-0000-000000000321','20000000-0000-0000-0000-000000000321','revoke','50000000-0000-0000-0000-000000000321');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000322',true);
do $q$begin
 begin perform public.sec_evidence_share_download('10000000-0000-0000-0000-000000000321','20000000-0000-0000-0000-000000000321','50000000-0000-0000-0000-000000000321');raise exception 'revoked share accepted';exception when insufficient_privilege then null;end;
end $q$;
reset role;rollback;
