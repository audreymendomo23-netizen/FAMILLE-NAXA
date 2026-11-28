#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_REPOSITORY:-}" == audreymendomo23-netizen/FAMILLE-NAXA && "${GITHUB_REF:-}" == refs/heads/work/grillad-foundation-20261127 ]] || exit 1
apk=apps/android/grillad/build/outputs/apk/debug/grillad-debug.apk
adb install -r "$apk"
adb shell am start -W -n cm.naxa.grillad/.MainActivity
for i in $(seq 1 20); do
  adb shell uiautomator dump /sdcard/grillad-ui.xml >/dev/null 2>&1 || true
  if adb shell cat /sdcard/grillad-ui.xml 2>/dev/null | grep -q 'GrillaD'; then break; fi
  sleep 1
done
adb shell cat /sdcard/grillad-ui.xml | grep -q 'GrillaD'
adb shell pidof cm.naxa.grillad
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
sleep 3
adb shell pidof cm.naxa.grillad
adb shell svc wifi disable
adb shell svc data disable
adb shell am force-stop cm.naxa.grillad
adb shell am start -W -n cm.naxa.grillad/.MainActivity
adb shell uiautomator dump /sdcard/grillad-ui.xml >/dev/null
adb shell cat /sdcard/grillad-ui.xml | grep -q 'GrillaD'
adb shell pidof cm.naxa.grillad
adb shell svc wifi enable
adb shell svc data enable
adb uninstall cm.naxa.grillad
echo 'PASS: virtual device APK installation, launch, rotation and offline restart (demo only)'
