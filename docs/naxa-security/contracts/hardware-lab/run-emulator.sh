#!/usr/bin/env bash
set -euo pipefail
mkdir -p security-hardware-results
# Never run synthetic injection against a physical phone.
test "$(adb shell getprop ro.kernel.qemu | tr -d '\r')" = "1"
{
  printf 'qualification=VIRTUAL\nphysical_certified=false\ncommit=%s\n' "$(git rev-parse HEAD)"
  adb shell getprop ro.build.version.sdk
  adb shell getprop ro.product.model
  adb shell pm list features
} > security-hardware-results/device-capabilities.txt
trap 'adb logcat -d -s SECURITY_VIRTUAL_LAB:I AndroidRuntime:E > security-hardware-results/android-lab.log || true' EXIT
gradle --no-daemon :naxa-security:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=cm.naxa.naxasecurity.SecurityVirtualHardwareTest 2>&1 | tee security-hardware-results/gradle.log
# A successful task with no test result is not acceptable.
python3 - <<'PY'
import pathlib, xml.etree.ElementTree as ET
files=list(pathlib.Path("apps/android/naxa-security/build/outputs/androidTest-results/connected").rglob("TEST-*.xml"))
assert files, "Missing instrumented JUnit XML"
cases=[case for p in files for case in ET.parse(p).getroot().iter("testcase")]
expected={"qr01_nativeBitmapRoundTrip","qr02_malformedAndUnreadable","gps01_freshnessAccuracyAndBounds","gps02_androidMockProviderIsRejected","storage01_contentResolverAndSha256","storage02_bounds","device01_reportCapabilitiesWithoutCertification"}
passed={c.attrib.get("name") for c in cases if all(c.find(tag) is None for tag in ("failure","error","skipped"))}
assert expected <= passed, f"Missing or failed instrumented cases: {expected-passed}"
print(f"VIRTUAL qualification: {len(expected)} required cases passed; no physical certification.")
PY
