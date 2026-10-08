#!/usr/bin/env python3
"""Compute a topological build order for a GHC compiler tree.

GHC never discovers its build order by walking imports from Main: mkdependHS
computes a dependency order and the Makefile compiles in it. mhs, asked for
Main, walks the graph itself -- and in a tree with 31 boot modules that goes
wrong (DECISIONS.md D22): a module bound to its .hs-boot early is never
promoted to the real module, so a later ordinary import of it sees an interface
with no data constructors.

Compiling in dependency order with mhs's -C cache avoids the situation
entirely: every module is already built when its dependents are compiled.

`import {-# SOURCE #-} M` edges are dropped -- that is exactly what they are
for -- which is what makes the remaining graph acyclic.

    ghc622/tools/build-order.py [tree] > notes/phase2/build-order.txt
"""
import re, sys, os, importlib.util

R = os.environ.get("GHC_BOOTSTRAP_ROOT", "")


def code_lines(path):
    """Yield the code lines of a .hs or .lhs file.

    Old GHC is almost entirely LaTeX-style literate Haskell, so scanning an
    .lhs raw counts its prose -- and 1990s GHC prose marks up inline code as
    @thing@, which every heuristic here then misreads.
    """
    literate = path.endswith(".lhs")
    inside = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if literate:
                if line.startswith("\\begin{code}"):
                    inside = True
                    continue
                if line.startswith("\\end{code}"):
                    inside = False
                    continue
                if line.startswith(">"):          # bird tracks
                    yield line[1:]
                    continue
                if not inside:
                    continue
            yield line


IMPORT = re.compile(
    r"^\s*import\s+(?P<source>\{-#\s*SOURCE\s*#-\}\s*)?"
    r"(?:qualified\s+)?(?P<mod>[A-Z][\w.']*)")
MODULE = re.compile(r"^\s*module\s+([A-Z][\w.']*)")


def scan(tree, skip_dirs=("nativeGen",)):
    """module -> set of modules it needs *before* it can be compiled."""
    deps, defined = {}, {}
    for dp, _, files in os.walk(tree):
        if os.path.basename(dp) in skip_dirs:
            continue
        for f in sorted(files):
            if not f.endswith((".hs", ".lhs")):
                continue
            p = os.path.join(dp, f)
            name, imports = None, set()
            for line in code_lines(p):
                if line.lstrip().startswith("--"):
                    continue
                m = MODULE.match(line)
                if m and name is None:
                    name = m.group(1)
                m = IMPORT.match(line)
                if m and not m.group("source"):     # SOURCE edges are not edges
                    imports.add(m.group("mod"))
            if name is None:
                name = os.path.splitext(f)[0]
            defined[name] = p
            deps[name] = imports
    # only edges inside the tree constrain the order
    return {m: {d for d in ds if d in defined and d != m} for m, ds in deps.items()}, defined


def order(deps):
    """Depth-first topological sort; reports any cycle that survives."""
    seen, done, out, stack = set(), set(), [], []

    def visit(m):
        if m in done:
            return
        if m in seen:
            i = stack.index(m)
            print("cycle: " + " -> ".join(stack[i:] + [m]), file=sys.stderr)
            return
        seen.add(m); stack.append(m)
        for d in sorted(deps.get(m, ())):
            visit(d)
        stack.pop(); done.add(m); out.append(m)

    for m in sorted(deps):
        visit(m)
    return out


if __name__ == "__main__":
    tree = sys.argv[1] if len(sys.argv) > 1 else R + "/build/ghc-4.08.2/ghc/compiler"
    deps, defined = scan(tree)
    o = order(deps)
    print("\n".join(o))
    print("%d modules" % len(o), file=sys.stderr)
