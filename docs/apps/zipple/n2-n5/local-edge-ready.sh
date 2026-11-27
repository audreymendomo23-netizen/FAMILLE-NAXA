#!/usr/bin/env bash
set -euo pipefail
# Disposable project only. Probe both actual Edge workers with a harmless rejected request.
case "${API_URL:-}" in http://127.0.0.1:*|http://localhost:*) ;; *) echo "Refusing nonlocal endpoint"; exit 1;; esac
project=zipple-business-ci
edge="supabase_edge_runtime_$project"
probe(){
  local a b
  a=$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' -X OPTIONS -H 'Origin: https://zipple.test' -H 'Access-Control-Request-Method: POST' "$API_URL/functions/v1/zipple-n1/login" 2>/dev/null) || a=000
  b=$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' -X OPTIONS -H 'Origin: https://zipple.test' -H 'Access-Control-Request-Method: POST' "$API_URL/functions/v1/zipple-business/snapshot" 2>/dev/null) || b=000
  echo "ZIPPLE_EDGE_READINESS auth=$a business=$b"
  [[ "$a" == 204 && "$b" == 204 ]]
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
