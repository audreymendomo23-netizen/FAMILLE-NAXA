#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${DATABASE_URL:?DATABASE_URL is required}"
: "${BACKUP_ENCRYPTION_PASSPHRASE:?BACKUP_ENCRYPTION_PASSPHRASE is required}"
: "${BACKUP_OUTPUT_DIR:?BACKUP_OUTPUT_DIR is required}"
command -v pg_dump >/dev/null
command -v pg_restore >/dev/null
command -v gpg >/dev/null
command -v sha256sum >/dev/null

mkdir -p "$BACKUP_OUTPUT_DIR"
chmod 700 "$BACKUP_OUTPUT_DIR"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
name="${BACKUP_NAME:-naxa-services-postgres-$stamp}"
work="$(mktemp -d "$BACKUP_OUTPUT_DIR/.backup-work.XXXXXX")"
trap 'rm -rf "$work"' EXIT
passfile="$work/passphrase"
printf '%s' "$BACKUP_ENCRYPTION_PASSPHRASE" > "$passfile"
chmod 600 "$passfile"

pg_dump --dbname="$DATABASE_URL" --format=custom --no-owner --no-acl --file="$work/$name.dump"
pg_restore --list "$work/$name.dump" >/dev/null
output="$BACKUP_OUTPUT_DIR/$name.dump.gpg"
gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$passfile" \
  --symmetric --cipher-algo AES256 --output "$output" "$work/$name.dump"
sha256sum "$output" > "$output.sha256"
cat > "$output.manifest.json" <<MANIFEST
{
  "artifact": "$(basename "$output")",
  "format": "pg_dump_custom",
  "encryption": "GPG_symmetric_AES256",
  "createdAt": "$stamp",
  "checksumFile": "$(basename "$output").sha256",
  "restoreRequiresExplicitDatabaseConfirmation": true
}
MANIFEST
chmod 600 "$output" "$output.sha256" "$output.manifest.json"
echo "Backup created: $output"
