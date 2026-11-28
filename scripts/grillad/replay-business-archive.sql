-- Isolated CI recovery utility. No live grant, no hosted deployment.
-- Included inside the synthetic transaction by grillad_transverse_assertions.sql.
-- Restores all records in the v1 business archive, but not accounts or partner credentials.
create temporary table grillad_replay_session_guard(marker boolean) on commit drop;
create function pg_temp.grillad_replay_business(p jsonb,p_org uuid,p_site uuid) returns jsonb
language plpgsql security invoker set search_path=pg_catalog as $restore$
declare t text; cols text; n integer; got jsonb;counts jsonb:='{}'; expected text[]:=array['items','cash','cash_recounts','preparations','stock_adjustments','sales','cash_receipts','expenses','purchases','targets','dimension_targets','service_policy','service_revisions','daily_summary'];
begin
 if current_database() not in ('grillad_test','grillad_restore_test') or current_user<>'postgres' then raise exception 'ISOLATED_RESTORE_ONLY' using errcode='42501';end if;
 if p->>'format'='grillad-business-export-v2' then expected:=expected||array['attendance_policy','attendance','attendance_corrections','missing_departures','missing_arrivals','notice_preference','notice_read'];end if;
 if coalesce(p->>'format','') not in ('grillad-business-export-v1','grillad-business-export-v2') or p->>'org' is distinct from p_org::text or p->>'site' is distinct from p_site::text or jsonb_typeof(p->'tables') is distinct from 'object' or octet_length(p::text)>3100000 then raise exception 'RESTORE_SCOPE' using errcode='22023';end if;
 if (select count(*) from jsonb_object_keys(p->'tables'))<>cardinality(expected) then raise exception 'RESTORE_TABLE_SET' using errcode='22023';end if;
 foreach t in array expected loop
  if jsonb_typeof(p->'tables'->t) is distinct from 'array' then raise exception 'RESTORE_TABLE' using errcode='22023';end if;
  if jsonb_array_length(p->'tables'->t)>10000 or exists(select 1 from jsonb_array_elements(p->'tables'->t) x where jsonb_typeof(x)<>'object' or x->>'org' is distinct from p_org::text or x->>'site' is distinct from p_site::text) then raise exception 'RESTORE_ROW_SCOPE' using errcode='22023';end if;
 end loop;
 -- All parents precede children. No deletion, overwrite or ON CONFLICT bypass.
 foreach t in array expected loop
  execute format('select count(*) from grillad_private.%I where org=$1 and site=$2',t) into n using p_org,p_site;
  if n<>0 then raise exception 'RESTORE_TARGET_NOT_EMPTY' using errcode='22023';end if;
  select string_agg(quote_ident(a.attname),',' order by a.attnum) into cols from pg_attribute a where a.attrelid=to_regclass('grillad_private.'||t) and a.attnum>0 and not a.attisdropped and a.attgenerated='' and a.attidentity='';
  if cols is null then raise exception 'RESTORE_SCHEMA';end if;
  if t='attendance' then
   if exists(select 1 from jsonb_array_elements(p->'tables'->t) x where x->'photo' is distinct from 'null'::jsonb) then raise exception 'RESTORE_PHOTO_DENIED' using errcode='22023';end if;
   execute format('insert into grillad_private.%I(%s) select %s from jsonb_populate_recordset(null::grillad_private.%I,$1) order by paired_arrival nulls first',t,cols,cols,t) using p->'tables'->t;
  else
   execute format('insert into grillad_private.%I(%s) select %s from jsonb_populate_recordset(null::grillad_private.%I,$1)',t,cols,cols,t) using p->'tables'->t;
  end if;
  execute format('select coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text),''[]''::jsonb) from grillad_private.%I x where org=$1 and site=$2',t) into got using p_org,p_site;
  if got is distinct from p->'tables'->t then raise exception 'RESTORE_CONTENT_MISMATCH' using errcode='22023';end if;
  counts:=counts||jsonb_build_object(t,jsonb_array_length(got));
 end loop;
 return counts;
end $restore$;
