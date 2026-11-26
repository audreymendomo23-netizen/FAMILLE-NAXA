#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
passphrase="CI-only-not-a-production-secret-$(date +%s)"
source_url="${BACKUP_TEST_SOURCE_URL:?BACKUP_TEST_SOURCE_URL required}"
target_url="${BACKUP_TEST_TARGET_URL:?BACKUP_TEST_TARGET_URL required}"
source_name="$(psql "$source_url" -X -A -t -v ON_ERROR_STOP=1 -c 'select current_database()')"
target_name="$(psql "$target_url" -X -A -t -v ON_ERROR_STOP=1 -c 'select current_database()')"

[[ "$source_name" == "naxa_backup_source" && "$target_name" == "naxa_backup_target" && "$source_url" != "$target_url" ]] || { echo "Drill refused: only isolated test databases are allowed" >&2; exit 1; }
psql "$source_url" -X -v ON_ERROR_STOP=1 -f "$root/supabase/tests/drafts/naxa_services_postgres_bootstrap.sql"
for draft in naxa_services_v1.sql naxa_services_v2_activity_onboarding_management.sql naxa_services_v3_operations_rewards_sync.sql naxa_services_v4_supplier_accounting_forecast.sql naxa_services_referrals_v1.sql naxa_services_v5_customer_referrals_promotions.sql naxa_services_v6_notifications.sql naxa_services_v7_financial_controls.sql naxa_services_v8_subscription_payment.sql; do
  file="$root/supabase/drafts/$draft"
  [[ "$(tail -n 1 "$file")" == "rollback;" ]] || { echo "Unsafe draft: $draft" >&2; exit 1; }
  sed -E '$s/rollback;/commit/' "$file" | psql "$source_url" -X -v ON_ERROR_STOP=1
done
psql "$source_url" -X -v ON_ERROR_STOP=1 <<'SQL'
drop table if exists public.backup_restore_probe;
create table public.backup_restore_probe (id integer primary key, marker text not null);
insert into public.backup_restore_probe values (1, 'naxa-services-backup-drill-ok');
SQL

export DATABASE_URL="$source_url"
export BACKUP_ENCRYPTION_PASSPHRASE="$passphrase"
export BACKUP_OUTPUT_DIR="$tmp"
export BACKUP_NAME="naxa-services-ci-drill"
"$root/infra/backup/backup-postgres.sh"
export BACKUP_FILE="$tmp/naxa-services-ci-drill.dump.gpg"
export DESTINATION_DATABASE_URL="$target_url"
export BACKUP_RESTORE_ALLOW_DESTRUCTIVE="true"
export BACKUP_RESTORE_CONFIRM_DATABASE="$target_name"
# A failed restore must preserve an existing target marker. No hosted target allowed.
psql "$target_url" -X -v ON_ERROR_STOP=1 -c "create table public.backup_restore_probe(id integer primary key, marker text not null); insert into public.backup_restore_probe values (1, 'unchanged-before-restore');"
assert_unchanged() {
  [[ "$(psql "$target_url" -X -A -t -v ON_ERROR_STOP=1 -c "select marker from public.backup_restore_probe where id=1")" == "unchanged-before-restore" ]]
}
expect_rejected() {
  if "$@" >"$tmp/negative-restore.log" 2>&1; then echo "Unexpected restore acceptance" >&2; exit 1; fi
  assert_unchanged
}
expect_rejected env BACKUP_RESTORE_ALLOW_DESTRUCTIVE=false "$root/infra/backup/restore-postgres.sh"
expect_rejected env BACKUP_RESTORE_CONFIRM_DATABASE=incorrect "$root/infra/backup/restore-postgres.sh"
expect_rejected env BACKUP_ENCRYPTION_PASSPHRASE=incorrect-test-phrase "$root/infra/backup/restore-postgres.sh"
cp "$BACKUP_FILE" "$tmp/tampered.dump.gpg"
printf 'tampered' >> "$tmp/tampered.dump.gpg"
# Checksum sidecar deliberately retains the original digest with the new filename.
sed 's/naxa-services-ci-drill.dump.gpg/tampered.dump.gpg/' "$BACKUP_FILE.sha256" > "$tmp/tampered.dump.gpg.sha256"
expect_rejected env BACKUP_FILE="$tmp/tampered.dump.gpg" "$root/infra/backup/restore-postgres.sh"
echo "PASS: refusal of unapproved target, mismatched confirmation, wrong passphrase and tampered ciphertext; target preserved."
"$root/infra/backup/restore-postgres.sh"
actual="$(psql "$target_url" -X -A -t -v ON_ERROR_STOP=1 -c "select marker from public.backup_restore_probe where id = 1")"
[[ "$actual" == "naxa-services-backup-drill-ok" ]]
# Compare all NAXA SERVICES table RLS flags and effective client/server grants.
catalog_sql="select c.relname, c.relrowsecurity, has_table_privilege('anon', c.oid, 'SELECT'), has_table_privilege('authenticated', c.oid, 'SELECT'), has_table_privilege('service_role', c.oid, 'SELECT') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and left(c.relname,3)='ns_' order by c.relname;"
function_sql="select p.proname, pg_get_function_identity_arguments(p.oid), p.prosecdef, has_function_privilege('anon', p.oid, 'EXECUTE'), has_function_privilege('authenticated', p.oid, 'EXECUTE'), has_function_privilege('service_role', p.oid, 'EXECUTE') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and left(p.proname,3)='ns_' order by 1,2;"
for sql in "$catalog_sql" "$function_sql"; do
  psql "$source_url" -X -A -t -v ON_ERROR_STOP=1 -c "$sql" > "$tmp/source.security"
  psql "$target_url" -X -A -t -v ON_ERROR_STOP=1 -c "$sql" > "$tmp/target.security"
  test -s "$tmp/source.security"
  diff -u "$tmp/source.security" "$tmp/target.security"
done
for test_file in naxa_services_rls_runtime_test.sql naxa_services_subscription_payment.sql naxa_services_strict_site_management_scope.sql naxa_services_unbound_session_guards.sql naxa_services_push_only_notifications.sql naxa_services_bound_push_tokens.sql naxa_services_notification_device_deliveries.sql; do
  psql "$target_url" -X -v ON_ERROR_STOP=1 -f "$root/supabase/tests/drafts/$test_file"
done
echo "NAXA SERVICES schema, restored permissions and runtime regression drill passed."
