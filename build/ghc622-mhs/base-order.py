#!/usr/bin/env python3
"""Topological build order for libraries/base (GHC 6.2.2) from its import lines.

Modules: every .hs/.lhs under the ALL_DIRS of libraries/base/Makefile.
Edges: `import [qualified] M` lines; `{-# SOURCE #-}` imports are dropped
(they are satisfied by .hi-boot files, as GHC's own build does).
Modules outside the package (GHC.Prim, wired-in) are ignored.
Output: one module per line, dependencies first; ties by name.
"""
import os, re, sys, subprocess
root = sys.argv[1]
incdir = sys.argv[2]   # ghc/includes (MachDeps.h, config.h)
# Run cpp the way the driver does (-undef -traditional, the GHC defines), so
# #ifdef __HUGS__ / __NHC__ import blocks do not create false edges.
CPP = ["gcc", "-E", "-undef", "-traditional", "-x", "c", "-P",
       "-D__HASKELL1__=5", "-D__GLASGOW_HASKELL__=602", "-D__HASKELL98__",
       "-D__CONCURRENT_HASKELL__", "-I" + os.path.join(root, "include"), "-I" + incdir, "-"]
dirs = ["", "Control", "Control/Concurrent", "Control/Monad", "Control/Monad/ST",
        "Data", "Data/Generics", "Data/Array", "Data/Array/IO", "Data/STRef", "Debug",
        "Foreign", "Foreign/C", "Foreign/Marshal", "GHC", "System", "System/Console",
        "System/Mem", "System/IO", "System/Posix", "Text", "Text/Html",
        "Text/PrettyPrint", "Text/ParserCombinators", "Text/Regex", "Text/Show", "Text/Read"]
mods = {}
for d in dirs:
    p = os.path.join(root, d)
    if not os.path.isdir(p): continue
    for f in sorted(os.listdir(p)):
        if f.endswith(".hs") or f.endswith(".lhs"):
            m = (d.replace("/", ".") + "." if d else "") + f.rsplit(".", 1)[0]
            mods[m] = os.path.join(p, f)
imp = re.compile(r'^\s*(?:>\s*)?import\s+(?:qualified\s+)?([A-Z][\w.]*)', re.M)
src = re.compile(r'^\s*(?:>\s*)?import\s+\{-#\s*SOURCE\s*#-\}', re.M)
deps = {}
for m, f in mods.items():
    raw = open(f, encoding="latin-1").read()
    if f.endswith(".lhs"):
        raw = "\n".join(l[1:] if l.startswith(">") else "" for l in raw.splitlines()) if ">" in raw[:2000] and "\\begin{code}" not in raw else raw
        if "\\begin{code}" in raw:
            keep, out_l = False, []
            for l in raw.splitlines():
                if l.startswith("\\begin{code}"): keep = True; out_l.append(""); continue
                if l.startswith("\\end{code}"): keep = False; out_l.append(""); continue
                out_l.append(l if keep else "")
            raw = "\n".join(out_l)
    txt = subprocess.run(CPP, input=raw.encode("latin-1"), capture_output=True).stdout.decode("latin-1")
    ds = set()
    if "-fno-implicit-prelude" not in raw and m != "Prelude" and "Prelude" in mods:
        ds.add("Prelude")
    for line in txt.splitlines():
        if src.match(line): continue
        mm = imp.match(line)
        if mm and mm.group(1) in mods and mm.group(1) != m:
            ds.add(mm.group(1))
    deps[m] = ds
out, seen, onpath = [], set(), []
def visit(m):
    if m in seen: return
    if m in onpath:
        sys.stderr.write("cycle: %s\n" % " -> ".join(onpath + [m])); return
    onpath.append(m)
    for d in sorted(deps[m]): visit(d)
    onpath.pop(); seen.add(m); out.append(m)
for m in sorted(mods): visit(m)
for m in out: print(m)
