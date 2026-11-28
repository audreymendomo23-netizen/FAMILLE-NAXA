#!/usr/bin/env bash
# GRILLAD distribution only: reuse cached dependencies, reduce Maven load and back off on HTTP 429.
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_REPOSITORY:-}" == audreymendomo23-netizen/FAMILLE-NAXA && "${GITHUB_REF:-}" == refs/heads/work/grillad-foundation-20261127 ]] || exit 2
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Identical KSP artifact and pinned version used by gradle-ci.sh; no forced dependency refresh.
cat > "$tmp/grillad-plugin.init.gradle" <<'GRADLE'
beforeSettings { s ->
 s.pluginManagement.resolutionStrategy.eachPlugin {
  if (requested.id.id == 'com.google.devtools.ksp' && requested.version == '2.0.20-1.0.25') {
   useModule("com.google.devtools.ksp:symbol-processing-gradle-plugin:2.0.20-1.0.25")
  }
 }
}
GRADLE
build=(gradle --no-daemon --no-parallel --max-workers=2 --stacktrace -I "$tmp/grillad-plugin.init.gradle" :grillad:testDebugUnitTest :grillad:assembleDebug)
# A complete cache needs no Maven requests. A real build/test failure is not a cache miss.
if "${build[@]}" --offline 2>&1 | tee "$tmp/offline.log"; then
  exit 0
else
  rc=$?
fi
if ! grep -Eiq 'no cached (version|resource|listing)|not available for offline mode|offline mode.*(available|cached)|plugin .* was not found|could not resolve plugin artifact' "$tmp/offline.log"; then
  exit "$rc"
fi
echo 'Offline cache incomplete; resolving missing dependencies with bounded concurrency.'
for attempt in 1 2 3; do
  if "${build[@]}" 2>&1 | tee "$tmp/attempt.log"; then
    exit 0
  else
    rc=$?
  fi
  if (( attempt == 3 )) || ! grep -Eiq 'status code 429|HTTP[^[:digit:]]*429|429[[:space:]]+Too Many Requests' "$tmp/attempt.log"; then
    exit "$rc"
  fi
  delay=120
  if (( attempt == 2 )); then delay=300; fi
  echo "Maven rate limit (429); retry $((attempt+1))/3 after ${delay}s, retaining cache and pinned dependencies."
  sleep "$delay"
done
