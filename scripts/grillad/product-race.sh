#!/usr/bin/env bash
set -euo pipefail
# Only used by the dedicated disposable PostgreSQL CI matrix job.
[[ "${PGDATABASE:-}" == grillad_test && "${PGHOST:-}" == localhost ]] || { echo 'Refusing non-fixture database' >&2; exit 1; }
psql -X -v ON_ERROR_STOP=1 -f supabase/local-tests/grillad_product_race_setup.sql
worker() {
  local n="$1" q="$2" e="$3"
  psql -X -v ON_ERROR_STOP=1 -v actor="91000000-0000-0000-0000-00000000000$n" -v session="91000000-0000-0000-0000-00000000001$n" -v event="95000000-0000-0000-0000-00000000000$e" -v qty="$q" -f supabase/local-tests/grillad_product_race_worker.sql
}
worker 2 1 1 & p1=$!
worker 4 1 2 & p2=$!
worker 5 1 3 & p3=$!
failed=0
for p in "$p1" "$p2" "$p3"; do wait "$p" || failed=1; done
(( failed == 0 )) || exit 1
worker 2 2 4 & p1=$!
worker 4 2 5 & p2=$!
worker 5 2 6 & p3=$!
for p in "$p1" "$p2" "$p3"; do wait "$p" || failed=1; done
(( failed == 0 )) || exit 1
psql -X -v ON_ERROR_STOP=1 -f supabase/local-tests/grillad_product_race_verify.sql
