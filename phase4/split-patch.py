#!/usr/bin/env python3
"""Split the pristine-vs-working diff of a GHC 6.2.2 compiler tree into a
patch series, one concern per patch, with exact line numbers.

    split-patch.py --pristine <ghc-6.2.2 root> --tree <root holding ghc/compiler>
                   --conf series.conf --out <patch dir> [--exclude NAME]... [--dry-run]

How it works
  1. `diff -rN -U0` between <pristine>/ghc/compiler and <tree>/ghc/compiler
     (with the --exclude names, i.e. the generated files) gives every change
     as a zero-context hunk in *pristine* line coordinates.
  2. Each hunk gets a class: first from the manifest in series.conf
     (`hunk FILE@LINE CLASS`), then from the heuristics below (whitespace-only,
     `_scc_` removal, composition-dot spacing, ...). A hunk nobody claims is an
     error: the series must account for every byte of the tree.
  3. series.conf lists the patches in order, each owning one or more classes.
     Stage k of a file = pristine lines with the hunks of patches 1..k applied
     (bottom-up, so pristine coordinates stay valid). Patch k is `diff -u`
     of stage k-1 against stage k, so every patch applies with `patch -p1`
     exactly: no fuzz, no offsets.
  4. The last stage must equal the working tree byte for byte, or the script
     fails.

Files are handled as Latin-1 text so that every byte round-trips (Ctype.lhs
carries Latin-1 comment bytes in the pristine tree).
"""
import argparse, os, re, subprocess, sys, tempfile

# --------------------------------------------------------------------- config

def parse_conf(path):
    """series.conf -> (patches, manifest).
    patches: list of (name, [classes], header_lines); manifest: {file@line: class}"""
    patches, manifest, cur = [], {}, None
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#") and not line.startswith("  "):
                continue
            if line.startswith("patch "):
                _, name, classes = line.split(None, 2)
                cur = (name, classes.split(","), [])
                patches.append(cur)
            elif line.startswith("hunk "):
                _, key, cls = line.split()
                manifest[key] = cls
            elif line.startswith("  ") and cur is not None:
                cur[2].append(line[2:])
            else:
                sys.exit("series.conf: cannot parse line: %r" % line)
    return patches, manifest

# --------------------------------------------------------------------- diff

class Hunk:
    __slots__ = ("file", "old_start", "old_len", "old", "new", "cls",
                 "old_nonl", "new_nonl")
    def __init__(self, file, old_start, old_len):
        self.file, self.old_start, self.old_len = file, old_start, old_len
        self.old, self.new, self.cls = [], [], None
        self.old_nonl = self.new_nonl = False
    @property
    def key(self):
        return "%s@%d" % (self.file, self.old_start)

HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")

def run_diff(pristine, tree, excludes):
    cmd = ["diff", "-rN", "-U0"]
    for e in excludes:
        cmd += ["-x", e]
    cmd += [os.path.join(pristine, "ghc/compiler"), os.path.join(tree, "ghc/compiler")]
    p = subprocess.run(cmd, capture_output=True)
    if p.returncode not in (0, 1):
        sys.exit("diff failed: %s" % p.stderr.decode("latin-1"))
    return p.stdout.decode("latin-1")

def parse_hunks(text, tree):
    hunks, cur, file, last = [], None, None, None
    prefix = os.path.join(tree, "ghc/compiler") + "/"
    for line in text.split("\n"):
        if line.startswith("diff ") or line.startswith("--- "):
            continue
        if line.startswith("+++ "):
            path = line[4:].split("\t")[0]
            assert path.startswith(prefix), path
            file = path[len(prefix):]
            continue
        m = HUNK_RE.match(line)
        if m:
            cur = Hunk(file, int(m.group(1)), int(m.group(2)) if m.group(2) is not None else 1)
            hunks.append(cur)
            continue
        if cur is None:
            continue
        if line.startswith("-"):
            cur.old.append(line[1:]); last = "old"
        elif line.startswith("+"):
            cur.new.append(line[1:]); last = "new"
        elif line.startswith("\\"):          # "\ No newline at end of file"
            if last == "old": cur.old_nonl = True
            else: cur.new_nonl = True
    return hunks

# ------------------------------------------------------------- heuristics

MHS_COMMENT = re.compile(r"\s*(--|/\*)\s*mhs\b.*$")
INSTANCE_RE = re.compile(r"instance\s+.*\b(Functor|Applicative|MonadFail)\b")

def strip_mhs(s):
    return MHS_COMMENT.sub("", s)

def items(lines):
    """Comma-separated items of an import/export list fragment."""
    out = []
    for l in lines:
        out += [x.strip() for x in strip_mhs(l).split(",")]
    return [x for x in out if x]          # a trailing comma before a line break is not an item

def multiset_minus(a, b):
    a = list(a)
    for x in b:
        if x in a: a.remove(x)
        else: return None
    return a

def classify(h):
    old, new = h.old, h.new
    # WS: only trailing whitespace differs
    if old and len(old) == len(new) and all(o.rstrip() == n.rstrip() for o, n in zip(old, new)) \
            and any(o != n for o, n in zip(old, new)):
        return "WS"
    # SCC: a cost-centre annotation goes
    if any("_scc_" in o for o in old) and not any("_scc_" in strip_mhs(n) for n in new):
        return "SCC"
    # FFI: old-style foreign declarations
    if any("foreign import" in o or "foreign label" in o for o in old):
        return "FFI"
    # SEMI: leading ';' after 'do {' removed
    if old and len(old) == len(new) and all(o.lstrip().startswith(";") for o in old) \
            and all(o.lstrip()[1:].strip() == strip_mhs(n).strip() for o, n in zip(old, new)):
        return "SEMI"
    # DOT: composition dot spaced
    if old and len(old) == len(new) and all(n.replace(" . ", ".") == o for o, n in zip(old, new)) \
            and any(" . " in n for n in new):
        return "DOT"
    # TC: exactly one comma removed per line (trailing or doubled)
    def one_comma_less(o, n):
        n = strip_mhs(n).rstrip(); o = o.rstrip()
        if len(o) != len(n) + 1: return False
        return any(o[i] == "," and o[:i] + o[i+1:] == n for i in range(len(o)))
    if old and len(old) == len(new) and all(one_comma_less(o, n) for o, n in zip(old, new)):
        return "TC"
    # MON: Functor/Applicative/MonadFail instances added
    if any(INSTANCE_RE.search(n) for n in new):
        return "MON"
    # HIDE: Prelude hiding ((<>))
    if any("import Prelude hiding ((<>))" in n for n in new):
        return "HIDE"
    # DUP / ABS: import/export list item removed / added / opened
    oi, ni = items(old), items(new)
    if old and new:
        rem = multiset_minus(oi, ni)
        # one item dropped, or several dropped that all still occur (duplicates)
        if rem is not None and (len(rem) == 1 or (rem and all(r in ni for r in rem))):
            return "DUP"
        add = multiset_minus(ni, oi)
        if add is not None and len(add) == 1:
            return "ABS"
        if len(oi) == len(ni):
            diff = [(o, n) for o, n in zip(oi, ni) if o != n]
            if len(diff) == 1 and diff[0][1].replace("(..)", "", 1) == diff[0][0]:
                return "ABS"
    return None

# ---------------------------------------------------------------- stages

def read_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="latin-1", newline="") as fh:
        data = fh.read()
    # split on "\n" only: str.splitlines also splits on form feeds and C1
    # controls, both of which occur in GHC sources
    parts = data.split("\n")
    lines = [p + "\n" for p in parts[:-1]]
    if parts[-1]:
        lines.append(parts[-1])
    return lines

def apply_hunks(lines, hunks):
    """Apply U0 hunks (pristine coordinates) bottom-up."""
    lines = list(lines)
    for h in sorted(hunks, key=lambda h: (h.old_start, h.old_len), reverse=True):
        new = [n + "\n" for n in h.new]
        if h.new_nonl and new:
            new[-1] = new[-1][:-1]
        if h.old_len == 0:
            at = h.old_start           # insert after line old_start
            lines[at:at] = new
        else:
            at = h.old_start - 1
            assert len(lines) >= at + h.old_len, (h.key, len(lines))
            lines[at:at + h.old_len] = new
    return lines

def unified(label, old_text, new_text):
    with tempfile.NamedTemporaryFile("wb", delete=False) as a, \
         tempfile.NamedTemporaryFile("wb", delete=False) as b:
        a.write(old_text.encode("latin-1")); b.write(new_text.encode("latin-1"))
    try:
        p = subprocess.run(["diff", "-u", "--label", "a/ghc/compiler/" + label,
                            "--label", "b/ghc/compiler/" + label, a.name, b.name],
                           capture_output=True)
    finally:
        os.unlink(a.name); os.unlink(b.name)
    return p.stdout.decode("latin-1")

# ------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pristine", required=True)
    ap.add_argument("--tree", required=True)
    ap.add_argument("--conf", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--exclude", action="append", default=[])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--list", action="store_true", help="print every hunk with its class")
    a = ap.parse_args()

    patches, manifest = parse_conf(a.conf)
    cls2patch = {}
    for i, (name, classes, _) in enumerate(patches):
        for c in classes:
            if c in cls2patch:
                sys.exit("class %s owned by two patches" % c)
            cls2patch[c] = i

    hunks = parse_hunks(run_diff(a.pristine, a.tree, a.exclude), a.tree)
    unknown, unused = [], set(manifest)
    for h in hunks:
        if h.key in manifest:
            h.cls = manifest[h.key]; unused.discard(h.key)
        else:
            h.cls = classify(h)
        if h.cls is None:
            unknown.append(h)
        elif h.cls not in cls2patch:
            sys.exit("hunk %s has class %s which no patch owns" % (h.key, h.cls))
    if a.list:
        for h in hunks:
            print("%-8s %s  -[%s] +[%s]" % (h.cls, h.key,
                  " / ".join(x.strip() for x in h.old)[:60],
                  " / ".join(x.strip() for x in h.new)[:60]))
    if unused:
        print("warning: manifest entries matching no hunk: %s" % ", ".join(sorted(unused)),
              file=sys.stderr)
    if unknown:
        print("ERROR: %d hunk(s) with no class; add `hunk FILE@LINE CLASS` to series.conf:"
              % len(unknown), file=sys.stderr)
        for h in unknown:
            print("  %s\n    -%s\n    +%s" % (h.key, " / ".join(h.old)[:200],
                                              " / ".join(h.new)[:200]), file=sys.stderr)
        sys.exit(1)

    files = sorted({h.file for h in hunks})
    by_file = {f: [h for h in hunks if h.file == f] for f in files}
    pristine = {f: read_lines(os.path.join(a.pristine, "ghc/compiler", f)) for f in files}
    target = {f: read_lines(os.path.join(a.tree, "ghc/compiler", f)) for f in files}

    # stage k content per file
    stages = []
    for k in range(len(patches)):
        st = {}
        for f in files:
            hs = [h for h in by_file[f] if cls2patch[h.cls] <= k]
            st[f] = apply_hunks(pristine[f], hs)
        stages.append(st)
    for f in files:
        if stages[-1][f] != target[f]:
            sys.exit("stage reconstruction of %s does not match the tree" % f)

    if a.dry_run:
        for i, (name, classes, _) in enumerate(patches):
            n = sum(1 for h in hunks if cls2patch[h.cls] == i)
            fs = len({h.file for h in hunks if cls2patch[h.cls] == i})
            print("%s  %3d hunks  %3d files  [%s]" % (name, n, fs, ",".join(classes)))
        return

    os.makedirs(a.out, exist_ok=True)
    for stale in os.listdir(a.out):
        if stale.endswith(".patch"):
            os.unlink(os.path.join(a.out, stale))
    for i, (name, classes, header) in enumerate(patches):
        prev = pristine if i == 0 else stages[i - 1]
        body, nfiles = [], 0
        for f in files:
            if prev[f] != stages[i][f]:
                body.append(unified(f, "".join(prev[f]), "".join(stages[i][f])))
                nfiles += 1
        if not body:
            print("warning: %s is empty" % name, file=sys.stderr)
        text = "\n".join(header) + "\n\n" + "".join(body)
        with open(os.path.join(a.out, name + ".patch"), "w", encoding="latin-1", newline="") as fh:
            fh.write(text)
        n = sum(1 for h in hunks if cls2patch[h.cls] == i)
        print("%s.patch  %3d hunks  %3d files" % (name, n, nfiles))
    print("%d hunks, %d files, %d patches" % (len(hunks), len(files), len(patches)))

if __name__ == "__main__":
    main()
