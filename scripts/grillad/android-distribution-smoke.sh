#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_REPOSITORY:-}" == audreymendomo23-netizen/FAMILLE-NAXA && "${GITHUB_REF:-}" == refs/heads/work/grillad-foundation-20261127 ]] || exit 2
apk=apps/android/grillad/build/outputs/apk/debug/grillad-debug.apk
test -s "$apk"
mkdir -p grillad-startup-check
adb shell wm size 1080x1920
adb shell wm density 420
adb install -r "$apk"
adb shell pm clear cm.naxa.grillad
adb shell am start -W -n cm.naxa.grillad/.MainActivity
for i in $(seq 1 12); do
  adb shell uiautomator dump /sdcard/grillad-startup.xml >/dev/null 2>&1 || true
  adb pull /sdcard/grillad-startup.xml grillad-startup-check/window.xml >/dev/null 2>&1 || true
  if grep -q 'content-desc="Grillade sur braises"' grillad-startup-check/window.xml 2>/dev/null && grep -q 'text="Connexion"' grillad-startup-check/window.xml; then break; fi
  sleep 2
done
adb exec-out screencap -p > grillad-startup-check/login.png
python3 - <<'PY'
import xml.etree.ElementTree as ET
root=ET.parse('grillad-startup-check/window.xml').getroot()
nodes=list(root.iter('node'))
assert any(n.get('content-desc')=='Grillade sur braises' for n in nodes), 'Photo missing from actual installed APK'
assert any(n.get('text')=='Connexion' for n in nodes), 'Commercial authentication not visible'
assert not any('Démo locale' in n.get('text','') or 'Service momentanément indisponible' in n.get('text','') for n in nodes), 'Demo or unavailable fallback opened'
print('PASS: actual distributed APK opens L’Atelier login with original photograph')
PY
