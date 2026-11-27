"""CI-only metadata, no env, request payload, credentials or raw Docker logs."""
import pathlib, subprocess, xml.etree.ElementTree as ET, re

prefix="supabase_"
project="_zipple-business-ci"
for service in ("edge_runtime","kong","auth","rest","db"):
    name=prefix+service+project
    r=subprocess.run(["docker","inspect","--format","{{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} restarts={{.RestartCount}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}",name],capture_output=True,text=True)
    print(service, r.stdout.strip() if r.returncode==0 else "not available")
    if service in ("edge_runtime","kong"):
        log=subprocess.run(["docker","logs","--tail","300",name],capture_output=True,text=True)
        raw=log.stdout+log.stderr
        for label,pattern in [("boot_failure",r"(?i)worker boot error|failed to boot|boot failure"),("oom",r"(?i)out of memory|memory limit|oomkill"),("connection_refused",r"(?i)connection refused|connect\(\) failed"),("timeout",r"(?i)timed?\s*out|deadline exceeded"),("upstream",r"(?i)upstream.*(?:error|invalid|closed|failed)")]:
            print(service,label,len(re.findall(pattern,raw)))
root=pathlib.Path("apps/android/zipple/build/outputs/androidTest-results/connected")
for file in root.rglob("*.xml"):
    try:
        for case in ET.parse(file).getroot().iter("testcase"):
            failure=case.find("failure")
            if failure is not None:
                # Extract only the stable test step label and exception class, not arbitrary payloads.
                raw=(failure.get("message") or "")+"\n"+(failure.text or "")
                match=re.search(r"ZIPPLE_BULK2_STEP_FAILED: ([^\r\n]{1,180})",raw)
                step=match.group(1) if match else "unclassified"
                if not re.fullmatch(r"[\w .,:—’/()\-]+",step): step="unclassified"
                cause=re.search(r"Caused by: ([\w.$]+)",raw)
                print("ANDROID_FAILURE",case.get("name","unknown"),step,"cause="+(cause.group(1) if cause else "not captured"))
                # Whitelist test-authored assertion labels, never raw actual values or request data.
                for label in ("persisted table zone","persisted seating capacity","cancelled booking must persist","cancelled waiting entry must disappear","seated booking must persist","completed booking must persist after table close","completed waiting entry must disappear","booking is seated before closing","reservation must open session","waitlist must open session","close reservation table","close waiting table"):
                    if label in raw:
                        print("ANDROID_ASSERTION_LABEL",label)
    except (OSError,ET.ParseError):
        print("ANDROID_REPORT_UNREADABLE")
