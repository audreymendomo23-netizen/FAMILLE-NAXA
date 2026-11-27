import csv, json, os, pathlib, re, subprocess, sys
root=pathlib.Path("docs/apps/zipple")
wave=int(os.environ["ZIPPLE_ACCEPTANCE_WAVE"])
assert 1<=wave<=4
with (root/"REGISTRE_RECETTES_B2_B6.csv").open(encoding="utf-8",newline="") as f:
    rows=list(csv.DictReader(f))
assert len(rows)==179 and len({r["id"] for r in rows})==179
# Explicit executable scenario bindings; never equate a partial marker with exhaustive acceptance.
bindings={
 "B2-019":1,"B2-022":1,"B2-032":1,"B3-003":1,
 "B3-016":2,"B3-019":2,"B4-017":2,"B4-020":2,"B4-022":2,"B4-023":2,
 "B4-034":3,"B5-003":3,"B5-004":3,"B5-005":3,"B5-006":3,"B5-007":3,"B5-008":3,"B5-009":3
}
selected=rows[(wave-1)*50:wave*50]
assert len(selected)==(50 if wave<4 else 29)
report=[]
for r in selected:
    case=r["id"]
    print("ZIPPLE_ACCEPTANCE_START",case,flush=True)
    suite=bindings.get(case)
    result={"id":case,"historical":r["statut"],"expected":r["action_resultat_attendu"],"commit":os.environ.get("GITHUB_SHA","local")}
    if suite:
        command=["node","--test","--test-name-pattern="+case,str(root/"n2-n5"/f"local-wave{suite}-business.test.mjs")]
        p=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        print(p.stdout,flush=True)
        full=bool(re.search(r"ZIPPLE_QA_CASE_PASS "+case+r"\b",p.stdout))
        partial=bool(re.search(r"ZIPPLE_QA_CASE_PARTIAL (?:B[2-6]-\d{3} )*"+case+r"\b",p.stdout))
        result["outcome"]="FAILED" if p.returncode or not (full or partial) else ("PASS" if full else "PARTIAL")
        result["exit_code"]=p.returncode
    elif case=="B2-025":
        result["outcome"]="INTEGRATED_SUITE";result["suite"]="web-guest-offline"
    elif r["statut"]=="D":
        result["outcome"]="BLOCKED_EXTERNAL";result["reason"]=r["preuve_ou_reserve"]
    else:
        result["outcome"]="NO_INDEPENDENT_SCENARIO";result["reason"]=r["preuve_ou_reserve"]
    report.append(result)
    print("ZIPPLE_ACCEPTANCE_RESULT",case,result["outcome"],flush=True)
out=pathlib.Path(os.environ["RUNNER_TEMP"])/"zipple-workspace-evidence"
out.mkdir(parents=True,exist_ok=True)
(out/f"acceptance-wave-{wave}.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
print("ZIPPLE_ACCEPTANCE_WAVE",wave,len(report),flush=True)
# Report gaps honestly; independent executed failures must fail the lane.
sys.exit(int(any(r["outcome"]=="FAILED" for r in report)))
