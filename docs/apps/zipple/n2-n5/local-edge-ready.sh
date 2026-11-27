#!/usr/bin/env bash
set -euo pipefail
# Disposable project only. Probe both actual Edge workers with a harmless rejected request.
case "${API_URL:-}" in http://127.0.0.1:*|http://localhost:*) ;; *) echo "Refusing nonlocal endpoint"; exit 1;; esac
project=zipple-business-ci
edge="supabase_edge_runtime_$project"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
http(){
  local output=$1; shift
  curl -sS --connect-timeout 5 --max-time 15 -o "$scratch/$output" -w '%{http_code}' "$@" 2>/dev/null || printf '000'
}
probe(){
  local auth biz gotrue rest
  auth=$(http auth -X POST -H 'Origin: https://zipple.test' -H 'Content-Type: application/json' --data '{"app_id":"ZIPPLE"}' "$API_URL/functions/v1/zipple-n1/login")
  biz=$(http business -X POST -H 'Origin: https://zipple.test' -H 'Content-Type: application/json' --data '{"app_id":"ZIPPLE"}' "$API_URL/functions/v1/zipple-business/snapshot")
  gotrue=$(http gotrue -H "apikey: ${ANON_KEY:?missing local anon key}" "$API_URL/auth/v1/health")
  rest=$(http rest -H "apikey: ${SERVICE_ROLE_KEY:?missing local service key}" -H "Authorization: Bearer $SERVICE_ROLE_KEY" "$API_URL/rest/v1/zp_members?select=id&limit=0")
  echo "ZIPPLE_EDGE_READINESS auth_post=$auth business_post=$biz gotrue=$gotrue postgrest=$rest"
  [[ "$auth" == 400 && "$biz" == 401 && "$gotrue" == 200 && "$rest" == 200 ]] || return 1
  python3 - "$scratch" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1])
try:
    assert json.loads((p/"auth").read_text()) == {"error":"INVALID"}
    assert json.loads((p/"business").read_text()) == {"error":"DENIED"}
    assert json.loads((p/"rest").read_text()) == []
except (OSError, ValueError, AssertionError):
    print("ZIPPLE_EDGE_RESPONSE_CONTRACT_MISMATCH")
    sys.exit(1)
PY
}
for attempt in 1 2 3; do
  if probe; then echo "ZIPPLE_LOCAL_EDGE_READY"; exit 0; fi
  sleep 3
done
# Recovery of the disposable worker only; no database restart or replay of business mutations.
if [[ "$(docker inspect --format '{{.Name}}' "$edge" 2>/dev/null || true)" == "/$edge" ]]; then
  docker inspect --format 'edge status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}}' "$edge"
  docker restart --time 10 "$edge" >/dev/null
else
  echo "Disposable Edge worker not found"; exit 1
fi
for attempt in 1 2 3 4 5 6; do
  if probe; then echo "ZIPPLE_LOCAL_EDGE_RECOVERED"; exit 0; fi
  sleep 5
done
echo "ZIPPLE_LOCAL_EDGE_UNAVAILABLE"
docker inspect --format 'edge status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}}' "$edge" || true
exit 1
