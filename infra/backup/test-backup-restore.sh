#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
passphrase="CI-only-not-a-production-secret-$(date +%s)"
source_url="${BACKUP_TEST_SOURCE_URL:?BACKUP_TEST_SOURCE_URL required}"
target_url="${BACKUP_TEST_TARGET_URL:?BACKUP_TEST_TARGET_URL required}"
target_name="$(psql "$target_url" -X -A -t -v ON_ERROR_STOP=1 -c 'select current_database()')"

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
"$root/infra/backup/restore-postgres.sh"
actual="$(psql "$target_url" -X -A -t -v ON_ERROR_STOP=1 -c "select marker from public.backup_restore_probe where id = 1")"
[[ "$actual" == "naxa-services-backup-drill-ok" ]]
echo "Backup/restore drill passed."
