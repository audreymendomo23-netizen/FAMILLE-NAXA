\set ON_ERROR_STOP on
begin;
set local role zipple_n0_authenticated;
select set_config('request.jwt.claim.sub','owner-a',true);
do $$ begin
 if (select count(*) from zipple_n0.business_records)<>1 then raise exception 'org isolation'; end if;
 if (select amount from zipple_n0.quote_for_org('a','ACCESS','monthly')) is distinct from 5000 then raise exception 'access month'; end if;
 if (select amount from zipple_n0.quote_for_org('a','ACCESS','annual')) is distinct from 50000 then raise exception 'access annual'; end if;
 if (select amount from zipple_n0.quote_for_org('a','PREMIUM','monthly')) is distinct from 18000 then raise exception 'premium month'; end if;
 if (select amount from zipple_n0.quote_for_org('a','PREMIUM','annual')) is distinct from 180000 then raise exception 'premium annual'; end if;
 if (select service_months from zipple_n0.quote_for_org('a','ACCESS','annual')) is distinct from 12 or (select paid_months from zipple_n0.quote_for_org('a','ACCESS','annual')) is distinct from 10 then raise exception 'annual duration'; end if;
 if exists(select 1 from zipple_n0.quote_for_org('a','ACCESS','3')) or exists(select 1 from zipple_n0.quote_for_org('a','ACCESS','6')) or exists(select 1 from zipple_n0.quote_for_org('a','ACCESS','quarterly')) or exists(select 1 from zipple_n0.quote_for_org('a','ACCESS','semiannual')) then raise exception 'forbidden cadence'; end if;
 if exists(select 1 from zipple_n0.quote_for_org('b','ACCESS','monthly')) then raise exception 'cross org quote'; end if;
 if not zipple_n0.feature_allowed('a','cash') or zipple_n0.feature_allowed('a','multilevel_management') or zipple_n0.feature_allowed('a','video') or zipple_n0.feature_allowed('b','cash') then raise exception 'access rights'; end if;
 begin update zipple_n0.subscriptions set plan='PREMIUM' where org_id='a'; raise exception 'unauthorized write'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','owner-b',true);
do $$ begin
 if (select count(*) from zipple_n0.business_records)<>2 then raise exception 'premium sites'; end if;
 if not zipple_n0.feature_allowed('b','multilevel_management') or not zipple_n0.feature_allowed('b','cash') or not zipple_n0.feature_allowed('b','advanced_reports') then raise exception 'premium entitlement'; end if;
 if zipple_n0.feature_allowed('b','advanced_ai') or zipple_n0.feature_allowed('b','unknown_feature') then raise exception 'fail closed'; end if;
end $$;
select set_config('request.jwt.claim.sub','staff-b',true);
do $$ begin
 if (select count(*) from zipple_n0.business_records)<>1 or exists(select 1 from zipple_n0.business_records where site_id='b2') then raise exception 'staff site'; end if;
 if exists(select 1 from zipple_n0.quote_for_org('b','PREMIUM','annual')) or zipple_n0.feature_allowed('b','multilevel_management') then raise exception 'staff privilege'; end if;
end $$;
select set_config('request.jwt.claim.sub','owner-c',true);
do $$ begin
 if zipple_n0.feature_allowed('c','cash') or exists(select 1 from zipple_n0.business_records) then raise exception 'inactive'; end if;
end $$;
select set_config('request.jwt.claim.sub','revoked',true);
do $$ begin if exists(select 1 from zipple_n0.business_records) or exists(select 1 from zipple_n0.quote_for_org('b','ACCESS','monthly')) then raise exception 'revoked'; end if; end $$;
select set_config('request.jwt.claim.sub','other-app',true);
do $$ begin if exists(select 1 from zipple_n0.business_records) or zipple_n0.feature_allowed('b','cash') or exists(select 1 from zipple_n0.quote_for_org('b','ACCESS','annual')) then raise exception 'cross app'; end if; end $$;
reset role;
set local role zipple_n0_anon;
do $$ begin
 begin perform * from zipple_n0.business_records; raise exception 'anon read'; exception when insufficient_privilege then null; end;
 begin perform * from zipple_n0.quote_for_org('b','ACCESS','monthly'); raise exception 'anon quote'; exception when insufficient_privilege then null; end;
end $$;
rollback;
select 'ZIPPLE_N0_POSTGRES17_PASS: prices, annual, forbidden cadence, tenant, app, site, role, revoked, inactive, anonymous, optional grants, no client writes' as result;
