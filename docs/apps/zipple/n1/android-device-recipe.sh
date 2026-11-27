#!/usr/bin/env bash
# ZIPPLE only: retry a dependency resolution rate limit, never an instrumentation failure.
set -euo pipefail
for attempt in 1 2 3; do
  log="$(mktemp)"
  set +e
  args=()
  if [ "$attempt" -gt 1 ]; then args+=(--init-script docs/apps/zipple/n1/zipple-zxing-mirror.init.gradle); fi
  gradle --no-daemon "${args[@]}" :zipple:connectedDebugAndroidTest 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -eq 0 ]; then rm -f "$log"; exit 0; fi
  if [ "$attempt" -eq 3 ] || ! grep -Eq 'Could not resolve all files|Could not resolve com\.google\.zxing' "$log" || ! grep -Eq '429.*Too Many Requests|status code 429' "$log" || grep -Eq 'Tests [0-9]+/[0-9]+ completed|connectedDebugAndroidTest FAILED|compileDebugAndroidTestKotlin FAILED' "$log"; then
    rm -f "$log"
    exit "$rc"
  fi
  rm -f "$log"
  echo "ZIPPLE: Maven dependency rate limit, retry $attempt/2"
  sleep "$((attempt * 20))"
done
exit 1
