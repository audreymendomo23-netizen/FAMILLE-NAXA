do $$ declare n int; begin
select count(*) into n from pg_class c join pg_namespace s on s.oid=c.relnamespace where s.nspname='bootik' and c.relkind='r'; if n<20 then raise exception 'missing tables'; end if;
if exists(select 1 from pg_class c join pg_namespace s on s.oid=c.relnamespace where s.nspname='bootik' and c.relkind='r' and (not c.relrowsecurity or not c.relforcerowsecurity or has_table_privilege('anon',c.oid,'SELECT') or has_table_privilege('authenticated',c.oid,'INSERT'))) then raise exception 'unsafe grants or RLS'; end if;
if has_schema_privilege('anon','bootik','USAGE') or has_schema_privilege('authenticated','bootik','USAGE') then raise exception 'schema access'; end if;
end $$;
select 'BOOTIK_N0_DRAFT_ISOLATION_PASS';
