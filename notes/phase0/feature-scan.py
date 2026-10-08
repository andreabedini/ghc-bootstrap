#!/usr/bin/env python3
"""Scan Haskell sources for constructs a Hugs-98-era compiler cannot parse.

Heuristic and line-based on purpose: it is a triage tool for sizing a port,
not a parser. Run it over a candidate source tree to estimate how far it is
from what Hugs accepts.
"""
import re, sys, os, collections, importlib.util

def pattern_guard(line):
    """A real pattern guard, not a list comprehension.

    `[ e | x <- xs ]` is the dominant false positive, so a `|` with an
    unclosed `[` to its left is skipped; what remains must reach a `=` or a
    `->` after the `<-`, i.e. the guard concludes on this line.
    """
    for m in re.finditer(r"\|", line):
        i = m.start()
        if line[:i].count("[") > line[:i].count("]"):
            continue
        rest = line[i + 1:]
        if "<-" not in rest:
            continue
        after = rest.split("<-", 1)[1]
        if "->" in after or re.search(r"(?<![=<>/+*!$^&|:-])=(?!=|>)", after):
            return True
    return False


# (name, regex or predicate, note)
CHECKS = [
    ("pattern-guard",   pattern_guard,                                  "| Just x <- e ="),
    ("multiway-if",     re.compile(r"\bif\s*\|"),                       "if | c -> e"),
    ("lambda-case",     re.compile(r"\\case\b"),                        "\\case"),
    ("bang-pattern",    re.compile(r"(?<![\w)])!\w+\s*(?:=|->|<-)"),   "!x = e"),
    ("forall",          re.compile(r"\bforall\b"),                      "ScopedTypeVariables/RankN"),
    ("type-application",re.compile(r"(?<![\w)\]])@[A-Z(\[]"),           "f @Int"),
    ("gadt-syntax",     re.compile(r"\bdata\b.*\bwhere\b"),             "data T where"),
    ("type-family",     re.compile(r"\btype\s+(family|instance)\b"),    "type families"),
    ("deriving-strat",  re.compile(r"\bderiving\s+(newtype|anyclass|stock|via)\b"), "deriving strategies"),
    ("standalone-deriv",re.compile(r"^\s*deriving\s+instance\b"),       "deriving instance"),
    # needs a function *and* an argument before the arrow, or every
    # `(a -> Bool)` in a type signature matches
    ("view-pattern",    re.compile(r"\(\s*[a-z][\w.']*\s+[\w.'\"]+\s*->\s"), "(f x -> p)"),
    ("tuple-section",   re.compile(r"\(\s*,\s*\w|\w\s*,\s*\)"),         "(,x)"),
    ("cpp",             re.compile(r"^#\s*(if|ifdef|ifndef|define|include)"), "needs cpphs"),
    ("unboxed",         re.compile(r"\w#"),                             "primops / MagicHash"),
    ("rec-do",          re.compile(r"^\s*(rec|mdo)\b"),                 "RecursiveDo"),
]

# code_lines lives with the chain's import scanner, which uses it too.
_spec = importlib.util.spec_from_file_location("build_order", os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, os.pardir, "ghc622", "tools", "build-order.py"))
_bo = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_bo)
code_lines = _bo.code_lines


def scan(paths, exts=(".hs", ".lhs")):
    counts = collections.Counter()
    per_file = collections.defaultdict(collections.Counter)
    nlines = 0
    for root in paths:
        for dirpath, _, files in os.walk(root):
            for f in sorted(files):
                if not f.endswith(exts):
                    continue
                p = os.path.join(dirpath, f)
                for line in code_lines(p):
                    nlines += 1
                    if line.lstrip().startswith("--"):
                        continue
                    for name, rx, _ in CHECKS:
                        if rx(line) if callable(rx) else rx.search(line):
                            counts[name] += 1
                            per_file[p][name] += 1
    return counts, per_file, nlines

if __name__ == "__main__":
    paths = sys.argv[1:] or ["."]
    counts, per_file, nlines = scan(paths)
    print(f"{'construct':20} {'hits':>6} {'/kloc':>7}   note")
    print("-" * 68)
    for name, _, note in CHECKS:
        per = 1000.0 * counts[name] / nlines if nlines else 0.0
        print(f"{name:20} {counts[name]:>6} {per:>7.1f}   {note}")
    print(f"\n{nlines} code lines scanned\n")
    print("worst files (by pattern-guard + multiway-if + lambda-case):")
    hot = sorted(per_file.items(),
                 key=lambda kv: -(kv[1]["pattern-guard"] + kv[1]["multiway-if"] + kv[1]["lambda-case"]))
    for p, c in hot[:12]:
        tot = c["pattern-guard"] + c["multiway-if"] + c["lambda-case"]
        if tot:
            print(f"  {tot:4}  {p}")
