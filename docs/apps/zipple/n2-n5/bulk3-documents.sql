-- Private, immutable source-linked evidence. No public bucket, no client-side service role.
begin;
create table public.zp_finance_documents(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,request_id uuid not null,
 source_kind text not null check(source_kind in ('expense','purchase_receipt','supplier_payment','credit_payment','sale','credit_sale','deposit_in','deposit_out','supplier_return','supplier_refund')),
 source_id uuid not null,label text not null check(length(label) between 1 and 160),mime text not null check(mime in ('application/pdf','image/jpeg','image/png')),
 content bytea not null check(octet_length(content) between 8 and 2097152),sha256_hex text not null check(length(sha256_hex)=64),
 created_at timestamptz not null default now(),unique(member_id,request_id),unique(site_id,source_kind,source_id,sha256_hex),
 foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
alter table public.zp_finance_documents enable row level security;
revoke all on public.zp_finance_documents from public,anon,authenticated;
grant select,insert on public.zp_finance_documents to service_role;
create function public.zp_finance_document_add(p_access text,p_site uuid,p_request uuid,p_kind text,p_source uuid,p_label text,p_mime text,p_base64 text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_finance_documents;b bytea;d text;i uuid;lbl text:=trim(coalesce(p_label,''));begin
 m:=public.zp_erp_actor(p_access,p_site);
 if p_request is null or p_source is null or p_base64 is null or length(p_base64)>2796204 or length(lbl) not between 1 and 160 or p_mime is null or p_mime not in ('application/pdf','image/jpeg','image/png') or p_kind is null or p_kind not in ('expense','purchase_receipt','supplier_payment','credit_payment','sale','credit_sale','deposit_in','deposit_out','supplier_return','supplier_refund') then raise exception 'INVALID_DOCUMENT';end if;
 begin b:=decode(p_base64,'base64');exception when invalid_parameter_value or data_exception then raise exception 'INVALID_DOCUMENT';end;
 if octet_length(b) not between 8 and 2097152 or not (case p_mime when 'application/pdf' then substring(b from 1 for 5)=decode('255044462d','hex') when 'image/jpeg' then substring(b from 1 for 3)=decode('ffd8ff','hex') when 'image/png' then substring(b from 1 for 8)=decode('89504e470d0a1a0a','hex') else false end) then raise exception 'INVALID_DOCUMENT';end if;
 d:=encode(sha256(b),'hex');
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_finance_documents where member_id=m.id and request_id=p_request;
 if x.id is not null then
  if (x.site_id,x.source_kind,x.source_id,x.label,x.mime,x.sha256_hex) is distinct from (p_site,p_kind,p_source,lbl,p_mime,d) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;
 end if;
 if not exists(select 1 from public.zp_ledger_sources where org_id=m.org_id and site_id=p_site and kind=p_kind and source_id=p_source) then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_finance_documents where site_id=p_site and source_kind=p_kind and source_id=p_source and sha256_hex=d) then raise exception 'DOCUMENT_ALREADY_ATTACHED';end if;
 insert into public.zp_finance_documents(org_id,site_id,member_id,request_id,source_kind,source_id,label,mime,content,sha256_hex) values(m.org_id,p_site,m.id,p_request,p_kind,p_source,lbl,p_mime,b,d) returning id into i;return i;end $$;
create function public.zp_finance_documents_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('sources',coalesce((select jsonb_agg(to_jsonb(s) order by s.entry_date desc) from (select kind,source_id,entry_date,label,amount_xaf::text as amount_xaf from public.zp_ledger_sources where org_id=m.org_id and site_id=p_site and kind in ('expense','purchase_receipt','supplier_payment','credit_payment','sale','credit_sale','deposit_in','deposit_out','supplier_return','supplier_refund') order by entry_date desc,source_id limit 300)s),'[]'::jsonb),
 'can_review',m.role_code='promoteur','documents',coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at desc) from (select f.id,f.source_kind,f.source_id,f.label,f.mime,f.sha256_hex,octet_length(f.content) size_bytes,f.created_at,f.member_id,coalesce((select e.action from public.zp_finance_document_events e where e.document_id=f.id and e.action in ('reviewed','blocked') order by e.created_at desc,e.id desc limit 1),'unreviewed') review_state,(select count(*) from public.zp_finance_document_events e where e.document_id=f.id and e.action='download') download_count from public.zp_finance_documents f where f.org_id=m.org_id and f.site_id=p_site order by f.created_at desc limit 300)d),'[]'::jsonb));end $$;
-- Append-only evidence review and download audit; review is not an antivirus scan.
create table public.zp_finance_document_events(
 id uuid primary key default gen_random_uuid(),document_id uuid not null references public.zp_finance_documents(id),
 org_id uuid not null,site_id uuid not null,member_id uuid not null,request_id uuid,
 action text not null check(action in ('download','reviewed','blocked')),
 reason text,created_at timestamptz not null default clock_timestamp(),
 unique(member_id,request_id),foreign key(site_id,org_id) references public.zp_sites(id,org_id),
 foreign key(member_id,org_id) references public.zp_members(id,org_id));
alter table public.zp_finance_document_events enable row level security;
revoke all on public.zp_finance_document_events from public,anon,authenticated;
grant select,insert on public.zp_finance_document_events to service_role;
create function public.zp_finance_document_review(p_access text,p_site uuid,p_id uuid,p_request uuid,p_action text,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $review$
declare m public.zp_members;x public.zp_finance_documents;e public.zp_finance_document_events;i uuid;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);
 if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 if p_request is null or p_action is null or p_action not in ('reviewed','blocked') or length(why) not between 5 and 500 then raise exception 'INVALID_DOCUMENT';end if;
 select * into x from public.zp_finance_documents where id=p_id and org_id=m.org_id and site_id=p_site for share;if x.id is null then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into e from public.zp_finance_document_events where member_id=m.id and request_id=p_request;
 if e.id is not null then
 if (e.site_id,e.document_id,e.action,e.reason) is distinct from (p_site,p_id,p_action,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return e.id;end if;
 insert into public.zp_finance_document_events(document_id,org_id,site_id,member_id,request_id,action,reason) values(p_id,m.org_id,p_site,m.id,p_request,p_action,why) returning id into i;return i;end $review$;
create function public.zp_finance_document_read(p_access text,p_site uuid,p_id uuid) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_finance_documents;decision text;begin m:=public.zp_erp_actor(p_access,p_site);
 select * into x from public.zp_finance_documents where id=p_id and org_id=m.org_id and site_id=p_site;if x.id is null then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select action into decision from public.zp_finance_document_events where document_id=x.id and org_id=m.org_id and site_id=p_site and action in ('reviewed','blocked') order by created_at desc,id desc limit 1;
 if decision='blocked' then raise exception 'DOCUMENT_BLOCKED';end if;
 if encode(sha256(x.content),'hex')<>x.sha256_hex then raise exception 'DOCUMENT_INTEGRITY';end if;
 insert into public.zp_finance_document_events(document_id,org_id,site_id,member_id,action) values(x.id,m.org_id,p_site,m.id,'download');
 return jsonb_build_object('id',x.id,'mime',x.mime,'label',x.label,'sha256_hex',x.sha256_hex,'base64',replace(encode(x.content,'base64'),chr(10),''));end $$;
do $$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_finance_document_add','zp_finance_documents_snapshot','zp_finance_document_read','zp_finance_document_review') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
