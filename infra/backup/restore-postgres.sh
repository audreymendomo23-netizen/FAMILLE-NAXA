#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${BACKUP_FILE:?BACKUP_FILE is required}"
: "${DESTINATION_DATABASE_URL:?DESTINATION_DATABASE_URL is required}"
: "${BACKUP_ENCRYPTION_PASSPHRASE:?BACKUP_ENCRYPTION_PASSPHRASE is required}"
: "${BACKUP_RESTORE_ALLOW_DESTRUCTIVE:?Set BACKUP_RESTORE_ALLOW_DESTRUCTIVE=true after reviewing the target}"
: "${BACKUP_RESTORE_CONFIRM_DATABASE:?Set this to the exact destination database name}"
if [[ "$BACKUP_RESTORE_ALLOW_DESTRUCTIVE" != "true" ]]; then
  echo "Restore refused: destructive restore requires BACKUP_RESTORE_ALLOW_DESTRUCTIVE=true" >&2
  exit 20
fi
for command in psql pg_restore gpg sha256sum; do command -v "$command" >/dev/null; done
[[ -f "$BACKUP_FILE" ]] || { echo "Backup file not found" >&2; exit 21; }

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
passfile="$temporary/passphrase"
printf '%s' "$BACKUP_ENCRYPTION_PASSPHRASE" > "$passfile"
chmod 600 "$passfile"

if [[ -f "$BACKUP_FILE.sha256" ]]; then
  (cd "$(dirname "$BACKUP_FILE")" && sha256sum --check "$(basename "$BACKUP_FILE").sha256")
else
  echo "Checksum sidecar is missing" >&2
  exit 22
fi

actual_database="$(psql "$DESTINATION_DATABASE_URL" -X -A -t -v ON_ERROR_STOP=1 -c 'select current_database()')"
[[ -n "$actual_database" && "$actual_database" == "$BACKUP_RESTORE_CONFIRM_DATABASE" ]] || {
  echo "Restore refused: destination database confirmation does not match" >&2
  exit 23
}
if [[ "$actual_database" =~ (^|_)(prod|production)(_|$) ]] && [[ "${BACKUP_RESTORE_ALLOW_PRODUCTION:-}" != "true" ]]; then
  echo "Restore refused: production-like database needs BACKUP_RESTORE_ALLOW_PRODUCTION=true" >&2
  exit 24
fi

gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$passfile" \
  --decrypt --output "$temporary/restore.dump" "$BACKUP_FILE"
pg_restore --list "$temporary/restore.dump" >/dev/null
pg_restore --dbname="$DESTINATION_DATABASE_URL" --clean --if-exists --no-owner --exit-on-error --single-transaction "$temporary/restore.dump"
echo "Restore verified structurally into database: $actual_database"
