import os
LIB_DIR = r"c:\Users\Lenovo\develop\deviz_mvp\lib"
REPLACEMENTS = [
    ("\u00c3\u201e\u00c6\u2019", "\u0103"),
    ("\u00c3\u0192\u00c2\u00a2", "\u00e2"),
    ("\u00c3\u0192\u00c2\u00ae", "\u00ee"),
    ("\u00c3\u0192\u00c5\u00bd", "\u00ce"),
    ("\u00c3\u02c6\u00e2\u201e\u00a2", "\u0219"),
    ("\u00c3\u02c6\u00e2\u20ac\u00ba", "\u021b"),
    ("\u00c3\u02c6\u00c5\u00a1", "\u021a"),
    ("\u00c3\u00a2\u00e2\u201a\u00ac\u00c2\u00a2", "\u2022"),
    ("\u00c4\u0192", "\u0103"),
    ("\u00c3\u00a2", "\u00e2"),
    ("\u00c3\u00ae", "\u00ee"),
    ("\u00c8\u2122", "\u0219"),
    ("\u00c8\u203a", "\u021b"),
    ("\u00c5\u00a3", "\u0163"),
    ("\u00c5\u0178", "\u015f"),
    ("\u00c4\u201a", "\u0102"),
    ("\u00c3\u017d", "\u00ce"),
    ("\u00c3\u201a", "\u00c2"),
    ("\u00c8\u02dc", "\u0218"),
    ("\u00c8\u0161", "\u021a"),
    ("\u00c5\u017e", "\u015e"),
    ("\u00e2\u20ac\u00a2", "\u2022"),
    ("\u00e2\u20ac\u201c", "\u2013"),
    ("\u00e2\u20ac\u201d", "\u2014"),
    ("\u00e2\u20ac\u00a6", "\u2026"),
    ("\u00e2\u20ac\u02dc", "\u2018"),
    ("\u00e2\u20ac\u2122", "\u2019"),
    ("\u00e2\u20ac\u0153", "\u201c"),
    ("\u00e2\u20ac\u009d", "\u201d"),
    ("\u00e2\u2020\u2019", "\u2192"),
    ("\u00e2\u201a\u00ac", "\u20ac"),
    ("\u00ef\u00bf\u00bd", ""),
]
def fix(p):
    t = open(p, encoding="utf-8").read()
    r = t
    for b,g in REPLACEMENTS:
        if b in r: r = r.replace(b,g)
    if r != t:
        open(p,"w",encoding="utf-8",newline="").write(r)
        return True
    return False
n=0
for root,dirs,files in os.walk(LIB_DIR):
    dirs[:] = [d for d in dirs if "snapshot" not in d.lower()]
    for f in files:
        if f.endswith(".dart"):
            p=os.path.join(root,f)
            if fix(p):
                print("Fixed:",os.path.relpath(p,LIB_DIR))
                n+=1
print("Done. Fixed",n,"files.")
