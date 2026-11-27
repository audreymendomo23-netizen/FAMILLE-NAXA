import csv, json, pathlib, os
root=pathlib.Path("docs/apps/zipple")
with (root/"REGISTRE_RECETTES_B2_B6.csv").open(encoding="utf-8",newline="") as f:
    rows=list(csv.DictReader(f))
assert len(rows)==len({r["id"] for r in rows})
assert {r["bulk"] for r in rows}=={"2","3","4","5","6"}
assert all(r["statut"] in {"V","P","A","D"} for r in rows)
cases=[dict(id=r["id"],bulk=r["bulk"],wave=i//50+1,historical=r["statut"],expected=r["action_resultat_attendu"],execution="independent_test_registered" if r["id"] in {"B2-019","B2-022","B2-025","B2-032","B3-003","B3-016","B3-019","B4-017","B5-003","B5-005","B5-007","B5-009" else ("integrated_test_extended" if r["id"] in {"B3-010","B4-017","B5-005","B5-006","B5-007","B5-008","B5-009"} else ("external_dependency" if r["statut"]=="D" else "integrated_or_to_individualize"))) for i,r in enumerate(rows)]
manifest=json.loads((root/"n2-n5"/"qa-waves.json").read_text(encoding="utf-8"))
assert [sum(c["wave"]==w for c in cases) for w in range(1,5)]==[50,50,50,29]
assert [len(w["actions"]) for w in manifest["api"]]==[50,50,50,30]
out=pathlib.Path(os.environ.get("RUNNER_TEMP","."))/"zipple-qa-plan.json"
out.write_text(json.dumps(dict(commit=os.environ.get("GITHUB_SHA","local"),cases=cases,api_waves=manifest["api"]),ensure_ascii=False,indent=2),encoding="utf-8")
for c in cases: print("wave",c["wave"],c["id"],c["execution"])
print("QA_CASES",len(cases))
