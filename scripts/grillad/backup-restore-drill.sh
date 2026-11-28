#!/usr/bin/env bash
# Adaptation du drill NAXA SERVICES. Données CI synthétiques uniquement.
set -euo pipefail
umask 077
[[ "$GITHUB_ACTIONS" == true && "$PGHOST" == localhost && "$PGPORT" == 5432 && "$PGUSER" == postgres && "$PGDATABASE" == grillad_test ]] || { echo "Isolated CI only"; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export GNUPGHOME="$tmp/gnupg"
mkdir -m 700 "$GNUPGHOME"
container="$(docker ps --filter ancestor=postgres:17 --format '{{.ID}}')"
[[ "$container" =~ ^[a-f0-9]+$ ]]
[[ "$(psql -XAt -v ON_ERROR_STOP=1 -c 'select current_database()')" == grillad_test ]]
fixture=supabase/local-tests/grillad_auth_bridge_assertions.sql
[[ "$(tail -n 1 "$fixture")" == 'rollback;' ]]
sed '$s/^rollback;$/commit;/' "$fixture" | psql -X -v ON_ERROR_STOP=1
# Populate the newly added transverse domains in the isolated database before dump.
psql -X -v ON_ERROR_STOP=1 <<'SQL'
begin;
insert into grillad_private.referral_codes(org) values('b2000000-0000-0000-0000-000000000001');
insert into famille_core.support_tickets(id,user_id,app_id,organization_id,subject,description)
 select 'b7a00000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',id,'b2000000-0000-0000-0000-000000000001','Recovery fixture','Synthetic support text' from famille_core.applications where code='grillad';
insert into grillad_private.support_messages(id,ticket,author,author_kind,body)
 values('b7a00000-0000-0000-0000-000000000002','b7a00000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','customer','Synthetic conversation');
insert into grillad_private.backup_preferences(org,site,actor,frequency,local_minute,weekday,monthday)
 values('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','weekly',360,1,1);
commit;
SQL
docker exec "$container" createdb -U postgres grillad_restore_test
[[ "$(PGDATABASE=grillad_restore_test psql -XAt -v ON_ERROR_STOP=1 -c 'select current_database()')" == grillad_restore_test ]]
openssl rand -hex 32 > "$tmp/pass"
openssl rand -hex 32 > "$tmp/wrong"
docker exec "$container" pg_dump -U postgres -Fc grillad_test | gpg --batch --yes --no-symkey-cache --pinentry-mode loopback --passphrase-file "$tmp/pass" --symmetric --cipher-algo AES256 --output "$tmp/grillad.dump.gpg"
(cd "$tmp"; sha256sum grillad.dump.gpg > manifest.sha256; sha256sum -c manifest.sha256)
if gpg --batch --yes --no-symkey-cache --pinentry-mode loopback --passphrase-file "$tmp/wrong" --decrypt "$tmp/grillad.dump.gpg" > /dev/null 2>&1; then echo "Wrong passphrase accepted"; exit 1; fi
cp "$tmp/grillad.dump.gpg" "$tmp/tampered.gpg"
printf 'tampered' >> "$tmp/tampered.gpg"
[[ "$(sha256sum "$tmp/tampered.gpg" | cut -d' ' -f1)" != "$(cut -d' ' -f1 "$tmp/manifest.sha256")" ]]
[[ "$(PGDATABASE=grillad_restore_test psql -XAt -c "select count(*) from pg_namespace where nspname='grillad_private'")" == 0 ]]
(cd "$tmp"; sha256sum -c manifest.sha256)
# Verify decryption in full before restoration, without writing plaintext to disk.
gpg --batch --yes --no-symkey-cache --pinentry-mode loopback --passphrase-file "$tmp/pass" --decrypt "$tmp/grillad.dump.gpg" > /dev/null
gpg --batch --yes --no-symkey-cache --pinentry-mode loopback --passphrase-file "$tmp/pass" --decrypt "$tmp/grillad.dump.gpg" | docker exec -i "$container" pg_restore -U postgres --exit-on-error --single-transaction -d grillad_restore_test
catalog="select c.relname,c.relrowsecurity,has_table_privilege('anon',c.oid,'SELECT'),has_table_privilege('authenticated',c.oid,'SELECT'),has_table_privilege('service_role',c.oid,'SELECT') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='grillad_private' and c.relkind='r' order by c.relname"
funcs="select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),p.prosecdef,has_function_privilege('anon',p.oid,'EXECUTE'),has_function_privilege('authenticated',p.oid,'EXECUTE'),has_function_privilege('service_role',p.oid,'EXECUTE') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='grillad_private' or (n.nspname='public' and left(p.proname,8)='grillad_') order by 1,2,3"
for q in "$catalog" "$funcs"; do
  psql -XAt -v ON_ERROR_STOP=1 -c "$q" > "$tmp/source"
  PGDATABASE=grillad_restore_test psql -XAt -v ON_ERROR_STOP=1 -c "$q" > "$tmp/target"
  test -s "$tmp/source"; diff -u "$tmp/source" "$tmp/target"
done
while IFS= read -r tbl; do
  [[ "$tbl" =~ ^[a-z_]+$ ]]
  q="select count(*),md5(coalesce(string_agg(to_jsonb(x)::text,E'\\n' order by to_jsonb(x)::text),'')) from grillad_private.$tbl x"
  [[ "$(psql -XAt -v ON_ERROR_STOP=1 -c "$q")" == "$(PGDATABASE=grillad_restore_test psql -XAt -v ON_ERROR_STOP=1 -c "$q")" ]]
done < <(psql -XAt -v ON_ERROR_STOP=1 -c "select tablename from pg_tables where schemaname='grillad_private' order by tablename")
# Full synthetic shared-core and GRILLAD reference data round-trip; never run on hosted data.
while IFS='|' read -r schema tbl; do
 [[ "$schema" =~ ^[a-z_]+$ && "$tbl" =~ ^[a-z_]+$ ]]
 q="select count(*),md5(coalesce(string_agg(to_jsonb(x)::text,E'\\n' order by to_jsonb(x)::text),'')) from $schema.$tbl x"
 [[ "$(psql -XAt -v ON_ERROR_STOP=1 -c "$q")" == "$(PGDATABASE=grillad_restore_test psql -XAt -v ON_ERROR_STOP=1 -c "$q")" ]]
done < <(psql -XAt -v ON_ERROR_STOP=1 -c "select schemaname,tablename from pg_tables where schemaname in ('famille_core','famille_private','auth') order by 1,2")
PGDATABASE=grillad_restore_test psql -X -v ON_ERROR_STOP=1 <<'SQL'
begin;
set role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000011","app_metadata":{}}',true);
do $$declare o uuid:='b2000000-0000-0000-0000-000000000001';s uuid:='b3000000-0000-0000-0000-000000000001';d date:=(now() at time zone 'Africa/Douala')::date;
begin
 if jsonb_array_length(public.grillad_workspace())<>2 or (public.grillad_report(o,s,d,d,false,null,null,null)->>'ca')::int<>2000 then raise exception 'restored owner scope or totals';end if;
 begin perform count(*) from grillad_private.sales;raise exception 'restored private access leaked';exception when insufficient_privilege then null;end;
 if public.grillad_referral(o,s,'list')->>'code' is null then raise exception 'restored referral missing';end if;
 if public.grillad_backup_preferences(o,s)->>'frequency' is distinct from 'weekly' then raise exception 'restored schedule missing';end if;
 if public.grillad_support_thread(o,s,'b7a00000-0000-0000-0000-000000000001')->'messages'->0->>'body' is distinct from 'Synthetic conversation' then raise exception 'restored conversation missing';end if;
end $$;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"b1000000-0000-0000-0000-000000000012","app_metadata":{}}',true);
do $$begin begin perform public.grillad_workspace();raise exception 'revoked session restored';exception when insufficient_privilege then null;end;end $$;
rollback;
SQL
echo "GRILLAD: encrypted backup, integrity, restored rows, permissions and revoked session passed."
