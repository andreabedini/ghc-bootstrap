#!/usr/bin/env python3
"""Bucket the FAIL lines of a scan-*.tsv into failure classes.

Usage: phase2/scan-classify.py build/scan-6.0.tsv [...]

The buckets are deliberately coarse: the question this answers is "what *kind*
of work would it take", not "what is wrong with module X".
"""
import re, sys, collections

RULES = [
    ("unboxed / primop",   r"kind error|Type and|#\)|MutableByteArray|ByteArray#|Int#|Addr#|State#|RealWorld|unpackCString|\bI#|\bW#|\bC#"),
    ("module not found",   r"[Cc]annot find module|[Mm]odule not found|cannot open|does not exist"),
    ("undefined name",     r"undefined (variable|identifier|type|constructor)|not in scope|Undefined"),
    ("syntax / lexical",   r"cannot parse|parse error|Parse error|syntax|lexical|unexpected"),
    ("type error",         r"type error|cannot unify|no instance|ambiguous"),
    ("cpp / preprocessor", r"cpphs|callCommand|preprocess"),
    ("duplicate / clash",  r"duplicate|conflicting|multiply defined"),
]

def bucket(msg):
    for name, pat in RULES:
        if re.search(pat, msg):
            return name
    return "other"

for path in sys.argv[1:]:
    rows = [l.rstrip("\n").split("\t") for l in open(path) if l.strip()]
    ok   = [r for r in rows if r[0] == "OK"]
    fail = [r for r in rows if r[0] == "FAIL"]
    print(f"\n=== {path} ===")
    print(f"  {len(ok)}/{len(rows)} OK  ({100*len(ok)//max(len(rows),1)}%)   {len(fail)} FAIL")
    c = collections.Counter(bucket(r[2] if len(r) > 2 else "") for r in fail)
    for name, n in c.most_common():
        print(f"    {n:4d}  {name}")
    # a couple of concrete examples per bucket, for the write-up
    seen = collections.defaultdict(int)
    print("  --- examples ---")
    for r in fail:
        b = bucket(r[2] if len(r) > 2 else "")
        if seen[b] < 2:
            seen[b] += 1
            print(f"    [{b}] {r[1]}: {(r[2] if len(r)>2 else '')[:120]}")
