#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${SUPABASE_URL:-}" || -n "${DATABASE_URL:-}" || -n "${PGSERVICE:-}" ]]; then
  echo "REFUS: seules les connexions PostgreSQL locales directes sont autorisées." >&2
  exit 3
fi
for b in psql createdb dropdb; do command -v "$b" >/dev/null 2>&1 || { echo "BLOCKED: $b absent"; exit 2; }; done
export PGHOST=127.0.0.1
export PGPORT="${PGPORT:-5432}"
DB="famille_prompt_03_local_test_$$"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
createdb "$DB"
trap 'dropdb --if-exists "$DB" >/dev/null 2>&1 || true' EXIT
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/local-tests/0002_bootstrap_local_auth.sql"
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/drafts/0001_famille_core_proposed.sql"
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/migrations/0002_famille_core_rls.sql"
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/local-tests/0002_prompt_0_3_rls_assertions.sql"
echo "PASS: Prompt 0.3 local RLS scenarios."
