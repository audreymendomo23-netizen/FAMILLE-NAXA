#!/usr/bin/env bash
# Dedicated Firebase qualification: retry only explicit Maven HTTP 429 failures.
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_REPOSITORY:-}" == audreymendomo23-netizen/FAMILLE-NAXA && "${GITHUB_REF:-}" == refs/heads/work/grillad-foundation-20261127 ]] || exit 2
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for attempt in 1 2 3; do
  if bash scripts/grillad/gradle-ci.sh :grillad:testDebugUnitTest :grillad:assembleDebug 2>&1 | tee "$tmp/attempt.log"; then
    exit 0
  else
    rc=$?
  fi
  if (( attempt == 3 )) || ! grep -Eiq 'status code 429|HTTP[^[:digit:]]*429|429[[:space:]]+Too Many Requests' "$tmp/attempt.log"; then
    exit "$rc"
  fi
  delay=30
  if (( attempt == 2 )); then delay=90; fi
  echo "Maven rate limit (429); retry $((attempt+1))/3 in ${delay}s using existing dependency cache."
  sleep "$delay"
done
