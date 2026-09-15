#!/usr/bin/env python3
"""Module order for the stage-2 build of GHC 6.2.2's compiler proper.

phase2/build-order.py's import scan, restricted to the directories the
Makefile compiles for a no-GHCi, no-NCG build (ghci, ilxGen, javaGen,
nativeGen dropped; HsGeneric, DsMeta, TcSplice, Convert excluded as in
EXCLUDED_SRCS), plus one edge the textual scan cannot see: HsVersions.h
does `import qualified FastString` unless COMPILING_FAST_STRING is defined,
so every module that includes it depends on FastString (mkdependHS ran cpp
and saw this; the mhs probe's shims hid it).

    python3 make-order.py <compiler-src-dir> > order.txt     (module<TAB>path)
"""
import importlib.util, sys, re, os
R = os.environ["GHC_BOOTSTRAP_ROOT"]; tree = sys.argv[1]
spec = importlib.util.spec_from_file_location("bo", R + "/phase2/build-order.py")
bo = importlib.util.module_from_spec(spec); spec.loader.exec_module(bo)
deps, defined = bo.scan(tree, skip_dirs=("nativeGen", "ilxGen", "javaGen", "ghci"))
excl = {"HsGeneric", "DsMeta", "TcSplice", "Convert"}
for m, p in defined.items():
    if m in excl or m == "FastString":
        continue
    src = open(p, encoding="latin-1").read()
    if 'include "HsVersions.h"' in src and "define COMPILING_FAST_STRING" not in src:
        deps[m].add("FastString")
for m in bo.order(deps):
    if m in excl or "/ilxGen/tests/" in defined[m]:
        continue
    print("%s\t%s" % (m, defined[m][len(tree) + 1:]))
