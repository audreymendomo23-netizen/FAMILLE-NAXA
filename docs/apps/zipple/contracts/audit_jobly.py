"""Read-only JOBLY source inventory. Never extracts or executes archive members."""
import zipfile, pathlib, re, hashlib, json
p=pathlib.Path("jobly/Jobly-source-minimal (1).zip")
data=p.read_bytes()
print("Archive bytes:",len(data),"SHA256:",hashlib.sha256(data).hexdigest())
categories={"auth":r"auth|session|login","billing":r"billing|subscription|entitlement|payment","admin":r"admin|feature.flag","qr":r"qr|share.token","support":r"support|chat|whatsapp","notification":r"notif|push","ai":r"assistant|ai.core|openai|analytics","security":r"security|permission|rbac|audit","offline":r"offline|sync"}
with zipfile.ZipFile(p) as z:
    items=z.infolist()
    assert len(items)<30000
    assert sum(i.file_size for i in items)<250_000_000
    assert all(not i.flag_bits & 1 for i in items)
    assert all(not pathlib.PurePosixPath(i.filename).is_absolute() and ".." not in pathlib.PurePosixPath(i.filename).parts for i in items)
    bad=z.testzip()
    assert bad is None, "Corrupt archive"
    code=[i for i in items if not i.is_dir() and re.search(r"\.(tsx?|jsx?|mjs|cjs|kt|java|sql|py|dart|go|rs)$",i.filename,re.I) and not re.search(r"(^|/)(node_modules|dist|build|\.git|\.next|vendor)(/|$)",i.filename)]
    print("Archive entries:",len(items),"source candidates:",len(code))
    assert code, "No source files"
    for label,pat in categories.items():
        matches=[i for i in code if re.search(pat,i.filename,re.I)]
        print(label, "candidates:",len(matches))
        for i in matches[:12]:
            # Print names/hash and structural counts only; never raw source or config values.
            body=z.read(i)
            clean=re.sub(r"[^a-zA-Z0-9_./@()+ -]","?",i.filename)[:220]
            print(" ",clean,"bytes",len(body),"sha256",hashlib.sha256(body).hexdigest()[:16])
    print("JOBLY inventory PASS; semantic module compatibility still requires source review")
