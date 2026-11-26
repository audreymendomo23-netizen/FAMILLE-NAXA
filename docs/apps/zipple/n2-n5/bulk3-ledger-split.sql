-- Immutable accounting allocations and correction by reversal/reposting. Never edit a validated entry.
begin;
create table public.zp_ledger_allocations(
 entry_id uuid primary key references public.zp_ledger_entries(id),lines jsonb not null check(jsonb_typeof(lines)='array' and jsonb_array_length(lines) between 2 and 20));
create table public.zp_ledger_corrections(
 original_id uuid primary key references public.zp_ledger_entries(id),reversal_id uuid not null unique references public.zp_ledger_entries(id),
 replacement_id uuid not null unique references public.zp_ledger_entries(id),member_id uuid not null,request_id uuid not null,
 reason text not null check(length(reason) between 5 and 250),unique(member_id,request_id));
create function public.zp_ledger_validate_lines(p_org uuid,p_site uuid,p_total bigint,p_lines jsonb) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare l jsonb;a uuid;s text;amt bigint;d numeric:=0;c numeric:=0;out_lines jsonb:='[]';seen uuid[]:='{}';begin
 if jsonb_typeof(p_lines) is distinct from 'array' then raise exception 'INVALID_LEDGER_LINES';end if;
 if jsonb_array_length(p_lines) not between 2 and 20 then raise exception 'INVALID_LEDGER_LINES';end if;
 for l in select value from jsonb_array_elements(p_lines) loop
  if jsonb_typeof(l)<>'object' or coalesce(l->>'amount_xaf','') !~ '^[1-9][0-9]{0,17}$' then raise exception 'INVALID_LEDGER_LINES';end if;
  begin a:=(l->>'account_id')::uuid;amt:=(l->>'amount_xaf')::bigint;exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'INVALID_LEDGER_LINES';end;
  s:=l->>'side';if a is null or s is null or s not in ('debit','credit') or a=any(seen) or amt is null or amt<=0 or amt>p_total then raise exception 'INVALID_LEDGER_LINES';end if;
  if not exists(select 1 from public.zp_ledger_accounts where id=a and org_id=p_org and site_id=p_site) then raise exception 'DENIED';end if;
  seen:=array_append(seen,a);if s='debit' then d:=d+amt;else c:=c+amt;end if;
  out_lines:=out_lines||jsonb_build_array(jsonb_build_object('account_id',a,'side',s,'amount_xaf',amt::text));
 end loop;
 if d<>p_total or c<>p_total then raise exception 'INVALID_LEDGER_LINES';end if;return out_lines;end $$;
create function public.zp_ledger_lines_for(p_entry uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog,public as $$
 select coalesce(a.lines,jsonb_build_array(jsonb_build_object('account_id',e.debit_account,'side','debit','amount_xaf',e.amount_xaf::text),jsonb_build_object('account_id',e.credit_account,'side','credit','amount_xaf',e.amount_xaf::text))) from public.zp_ledger_entries e left join public.zp_ledger_allocations a on a.entry_id=e.id where e.id=p_entry;
$$;
create function public.zp_ledger_post_split(p_access text,p_site uuid,p_kind text,p_source uuid,p_request uuid,p_journal text,p_label text,p_lines jsonb) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_ledger_sources;e public.zp_ledger_entries;v_lines jsonb;i uuid;d uuid;c uuid;begin
 m:=public.zp_ledger_owner(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_ledger_sources where org_id=m.org_id and site_id=p_site and kind=p_kind and source_id=p_source;
 if x.source_id is null then raise exception 'LEDGER_SOURCE_UNAVAILABLE';end if;
 v_lines:=public.zp_ledger_validate_lines(m.org_id,p_site,x.amount_xaf,p_lines);
 select (l->>'account_id')::uuid into d from jsonb_array_elements(v_lines) l where l->>'side'='debit' limit 1;
 select (l->>'account_id')::uuid into c from jsonb_array_elements(v_lines) l where l->>'side'='credit' limit 1;
 select * into e from public.zp_ledger_entries where member_id=m.id and request_id=p_request;
 if e.id is not null then
  if (e.site_id,e.source_kind,e.source_id,e.journal_code,e.label) is distinct from (p_site,p_kind,p_source,upper(trim(p_journal)),trim(p_label)) or not exists(select 1 from public.zp_ledger_allocations a where a.entry_id=e.id and a.lines=v_lines) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return e.id;
 end if;
 i:=public.zp_ledger_post(p_access,p_site,p_kind,p_source,p_request,p_journal,d,c,p_label);
 insert into public.zp_ledger_allocations values(i,v_lines);return i;end $$;
create function public.zp_ledger_correct(p_access text,p_site uuid,p_entry uuid,p_request uuid,p_reason text,p_lines jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;e public.zp_ledger_entries;x public.zp_ledger_corrections;v_lines jsonb;rev_lines jsonb;rev uuid;repost uuid;d uuid;c uuid;why text:=trim(coalesce(p_reason,''));today date:=(now() at time zone 'Africa/Douala')::date;begin
 m:=public.zp_ledger_owner(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into e from public.zp_ledger_entries where id=p_entry and org_id=m.org_id and site_id=p_site;
 if e.id is null then raise exception 'DENIED';end if;
 if p_request is null or length(why) not between 5 and 250 or e.source_kind='correction_reverse' then raise exception 'INVALID_LEDGER_CORRECTION';end if;
 v_lines:=public.zp_ledger_validate_lines(m.org_id,p_site,e.amount_xaf,p_lines);
 select * into x from public.zp_ledger_corrections where member_id=m.id and request_id=p_request;
 if x.original_id is not null then
  if (x.original_id,x.reason) is distinct from (p_entry,why) or public.zp_ledger_lines_for(x.replacement_id)<>v_lines then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return jsonb_build_object('reversal_id',x.reversal_id,'replacement_id',x.replacement_id);
 end if;
 if exists(select 1 from public.zp_ledger_corrections where original_id=e.id) then raise exception 'LEDGER_ALREADY_CORRECTED';end if;
 if v_lines=public.zp_ledger_lines_for(e.id) then raise exception 'INVALID_LEDGER_CORRECTION';end if;
 if exists(select 1 from public.zp_ledger_closures where org_id=m.org_id and site_id=p_site and through_date>=today) then raise exception 'LEDGER_PERIOD_CLOSED';end if;
 select jsonb_agg(jsonb_set(l,'{side}',to_jsonb(case l->>'side' when 'debit' then 'credit' else 'debit' end)) order by n) into rev_lines from jsonb_array_elements(public.zp_ledger_lines_for(e.id)) with ordinality as z(l,n);
 insert into public.zp_ledger_entries(org_id,site_id,source_kind,source_id,entry_date,journal_code,label,debit_account,credit_account,amount_xaf,member_id,request_id)
 values(m.org_id,p_site,'correction_reverse',e.id,today,e.journal_code,why,e.credit_account,e.debit_account,e.amount_xaf,m.id,gen_random_uuid()) returning id into rev;
 insert into public.zp_ledger_allocations values(rev,rev_lines);
 select (l->>'account_id')::uuid into d from jsonb_array_elements(v_lines) l where l->>'side'='debit' limit 1;
 select (l->>'account_id')::uuid into c from jsonb_array_elements(v_lines) l where l->>'side'='credit' limit 1;
 insert into public.zp_ledger_entries(org_id,site_id,source_kind,source_id,entry_date,journal_code,label,debit_account,credit_account,amount_xaf,member_id,request_id)
 values(m.org_id,p_site,'correction_repost',e.id,today,e.journal_code,why,d,c,e.amount_xaf,m.id,gen_random_uuid()) returning id into repost;
 insert into public.zp_ledger_allocations values(repost,v_lines);
 insert into public.zp_ledger_corrections values(e.id,rev,repost,m.id,p_request,why);
 return jsonb_build_object('reversal_id',rev,'replacement_id',repost);end $$;
create or replace function public.zp_ledger_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_ledger_owner(p_access,p_site);
 return jsonb_build_object('accounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'code',code,'label',label,'section',section) order by code) from public.zp_ledger_accounts where org_id=m.org_id and site_id=p_site),'[]'::jsonb),
 'entries',coalesce((select jsonb_agg(to_jsonb(e) order by e.entry_date,e.created_at) from (select id,source_kind,source_id,entry_date,journal_code,label,debit_account,credit_account,amount_xaf::text as amount_xaf,created_at,public.zp_ledger_lines_for(id) as lines,exists(select 1 from public.zp_ledger_corrections c where c.original_id=zp_ledger_entries.id) as corrected from public.zp_ledger_entries where org_id=m.org_id and site_id=p_site)e),'[]'::jsonb),
 'pending',coalesce((select jsonb_agg(to_jsonb(s) order by s.entry_date,s.source_id) from (select kind,source_id,entry_date,amount_xaf::text as amount_xaf,label from public.zp_ledger_sources x where x.org_id=m.org_id and x.site_id=p_site and not exists(select 1 from public.zp_ledger_entries e where e.site_id=x.site_id and e.source_kind=x.kind and e.source_id=x.source_id))s),'[]'::jsonb),
 'closed_through',(select max(through_date) from public.zp_ledger_closures where org_id=m.org_id and site_id=p_site),
 'unknown_cost_receipts',(select count(distinct r.id) from public.zp_cash_receipts r join public.zp_sale_costs c on c.receipt_id=r.id where r.org_id=m.org_id and r.site_id=p_site and c.cost_xaf is null));end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_ledger_allocations','zp_ledger_corrections'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_ledger_validate_lines','zp_ledger_lines_for','zp_ledger_post_split','zp_ledger_correct') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
