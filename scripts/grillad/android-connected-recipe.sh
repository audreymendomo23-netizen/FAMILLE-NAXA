#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_REPOSITORY:-}" == audreymendomo23-netizen/FAMILLE-NAXA && "${GITHUB_REF:-}" == refs/heads/work/grillad-foundation-20261127 && "${GRILLAD_CI_LOCAL:-}" == 1 ]] || exit 1
[[ "${GRILLAD_LOCAL_API:-}" == http://127.0.0.1:54321 || "${GRILLAD_LOCAL_API:-}" == http://localhost:54321 ]] || exit 1
node scripts/grillad/local-real-auth.mjs serve >"$RUNNER_TEMP/grillad-android-gateway.log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; adb reverse --remove tcp:4182 2>/dev/null || true; adb uninstall cm.naxa.grillad.test >/dev/null 2>&1 || true; adb uninstall cm.naxa.grillad >/dev/null 2>&1 || true' EXIT
for i in $(seq 1 20); do if curl -s --max-time 1 http://127.0.0.1:4182/functions/v1/grillad >/dev/null; then break; fi; sleep 1; done
adb reverse tcp:4182 tcp:4182
adb install -r apps/android/grillad/build/outputs/apk/debug/grillad-debug.apk
adb install -r apps/android/grillad/build/outputs/apk/androidTest/debug/grillad-debug-androidTest.apk
adb shell run-as cm.naxa.grillad mkdir -p files
adb shell -T "run-as cm.naxa.grillad sh -c 'cat > files/grillad-recipe-accounts.json'" < "$RUNNER_TEMP/grillad-real-accounts.json"
adb shell am instrument -w -e class cm.naxa.grillad.NativeConnectedRecipeTest cm.naxa.grillad.test/androidx.test.runner.AndroidJUnitRunner | tee "$RUNNER_TEMP/grillad-native-instrumentation.log"
grep -Eq 'OK \(1 test\)' "$RUNNER_TEMP/grillad-native-instrumentation.log"
