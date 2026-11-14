#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${SUPABASE_URL:-}" || -n "${DATABASE_URL:-}" ]]; then echo "REFUS: Supabase URLs interdites dans les tests locaux." >&2; exit 3; fi
for b in psql createdb dropdb; do command -v "$b" >/dev/null 2>&1 || { echo "BLOCKED: $b absent"; exit 2; }; done
DB="${FAMILLE_TEST_DB:-famille_prompt_03_local_test}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dropdb --if-exists "$DB" >/dev/null 2>&1 || true
createdb "$DB"; trap 'dropdb --if-exists "$DB" >/dev/null 2>&1 || true' EXIT
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/local-tests/0002_bootstrap_local_auth.sql"
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/drafts/0001_famille_core_proposed.sql"
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/migrations/0002_famille_core_rls.sql"
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f "$ROOT/supabase/local-tests/0002_prompt_0_3_rls_assertions.sql"
echo "PASS: Prompt 0.3 local RLS scenarios."
