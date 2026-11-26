import zipfile, pathlib, re
p=pathlib.Path('jobly/Jobly-source-minimal (1).zip')
with zipfile.ZipFile(p) as z:
    names=[n for n in z.namelist() if not n.endswith('/')]
    assert names and len(names)<100000
    print('JOBLY_FILES',len(names))
    for group in ['auth','billing','entitlement','profile','document','notification','chat','admin','qr','test','feature']:
        hits=[n for n in names if re.search(group,n,re.I) and re.search(r'\.(ts|tsx|js|jsx|kt|sql|py|md)$',n,re.I)]
        print(group,len(hits),*hits[:15],sep='\n')
