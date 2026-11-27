import csv, json, pathlib, os
root=pathlib.Path("docs/apps/zipple")
with (root/"REGISTRE_RECETTES_B2_B6.csv").open(encoding="utf-8",newline="") as f:
    rows=list(csv.DictReader(f))
assert len(rows)==len({r["id"] for r in rows})
assert {r["bulk"] for r in rows}=={"2","3","4","5","6"}
assert all(r["statut"] in {"V","P","A","D"} for r in rows)
cases=[dict(id=r["id"],bulk=r["bulk"],historical=r["statut"],expected=r["action_resultat_attendu"],execution="independent_test_registered" if r["id"]=="B2-025" else ("external_dependency" if r["statut"]=="D" else "integrated_or_to_individualize")) for r in rows]
out=pathlib.Path(os.environ.get("RUNNER_TEMP","."))/"zipple-qa-plan.json"
out.write_text(json.dumps(dict(commit=os.environ.get("GITHUB_SHA","local"),cases=cases),ensure_ascii=False,indent=2),encoding="utf-8")
for c in cases: print(c["id"],c["execution"])
print("QA_CASES",len(cases))
