#!/usr/bin/env bash
set -euo pipefail
gradle --no-daemon :naxa-services:assembleDebug :naxa-services:assembleDebugAndroidTest
app="$(find apps/android/naxa-services/build/outputs/apk/debug -name '*.apk' -print -quit)"
testapk="$(find apps/android/naxa-services/build/outputs/apk/androidTest/debug -name '*.apk' -print -quit)"
test -s "$app"; test -s "$testapk"
adb install -r "$app"
adb install -r "$testapk"
run_phase() {
 local phase="$1"
 adb shell am instrument -w -r -e class cm.naxa.naxaservices.AttendanceRebootQualificationTest -e nsRebootPhase "$phase" cm.naxa.naxaservices.test/androidx.test.runner.AndroidJUnitRunner | tee "$RUNNER_TEMP/ns-reboot-$phase.log"
 grep -F 'OK (1 test)' "$RUNNER_TEMP/ns-reboot-$phase.log"
 ! grep -E 'FAILURES!!!|INSTRUMENTATION_FAILED|shortMsg=' "$RUNNER_TEMP/ns-reboot-$phase.log"
}
adb shell svc wifi disable
adb shell svc data disable
run_phase prepare
before="$(adb shell settings get global boot_count | tr -d '\r')"
[[ "$before" =~ ^[0-9]+$ ]]
adb reboot
adb wait-for-device
for attempt in $(seq 1 90); do
 if [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; then break; fi
 sleep 2
done
test "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1
after="$(adb shell settings get global boot_count | tr -d '\r')"
[[ "$after" =~ ^[0-9]+$ ]]
(( after > before ))
adb shell input keyevent 82
adb shell svc wifi disable
adb shell svc data disable
run_phase verify
echo 'PASS real emulator OS reboot, encrypted capture preserved, old boot replay rejected'
