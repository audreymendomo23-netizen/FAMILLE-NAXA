#!/usr/bin/env bash
set -euo pipefail
adb install -r apps/android/widemeet/build/outputs/apk/debug/widemeet-debug.apk
adb install -r apps/android/widemeet/build/outputs/apk/androidTest/debug/widemeet-debug-androidTest.apk
adb shell pm grant cm.naxa.widemeet android.permission.POST_NOTIFICATIONS
identity="$(node scripts/widemeet/live-fcm-identity.mjs identity)"
echo "::add-mask::$identity"
adb shell am instrument -w -r -e class cm.naxa.widemeet.LiveFcmInstrumentedTest -e wmCiOidc "$identity" cm.naxa.widemeet.test/androidx.test.runner.AndroidJUnitRunner > "$RUNNER_TEMP/wm-fcm-instrumentation.log"
unset identity
if grep -qE '^OK \(1 test\)' "$RUNNER_TEMP/wm-fcm-instrumentation.log"; then
  echo 'PASS WM FCM actual Android foreground notification and token cleanup'
else
  grep -E 'FAILURES!!!|Tests run:|INSTRUMENTATION_CODE:|java.lang.AssertionError:' "$RUNNER_TEMP/wm-fcm-instrumentation.log" | head -20 || true
  exit 1
fi
