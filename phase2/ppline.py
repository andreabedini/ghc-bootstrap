#!/usr/bin/env python3
"""Show a line of a GHC source file as mhs sees it, after unlit + cpphs.

mhs reports errors against post-preprocessing line numbers, which for GHC's
literate sources bear no relation to the .lhs. This replays the same two steps
mhs does (Compile.hs: unlit, then cpphs) and prints the neighbourhood.

    phase2/ppline.py <file.lhs> <line> [context]
"""
import sys, os, subprocess, tempfile

R = "/home/andrea/work/haskell/ghc-bootstrap"
T = R + "/build/ghc-4.08.2/ghc/compiler"


def unlit(path):                      # mirrors MicroHs Compile.hs:575-592
    # Note: outside a code block, blank and prose lines are DROPPED, not
    # blanked, so the output is shorter than the input and line numbers shift.
    out, incode = [], False
    for line in open(path, errors="replace"):
        l = line.rstrip("\n")
        if incode:
            if l == "\\end{code}":
                out.append(""); incode = False
            else:
                out.append(l)
        elif l == "\\begin{code}":
            out.append(""); incode = True
        elif l.startswith("#"):
            out.append(l)
        elif l.startswith(">"):
            out.append(" " + l[1:])
        # else: dropped
    return "\n".join(out) + "\n"


def main():
    path, line = sys.argv[1], int(sys.argv[2])
    ctx = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    tmp = os.environ.get("TMPDIR", "/tmp")
    src = os.path.join(tmp, "ppline.in.hs")
    dst = os.path.join(tmp, "ppline.out.hs")
    open(src, "w").write(unlit(path))
    subprocess.run([R + "/MicroHs/bin/cpphs", "--strip", "-D__MHS__",
                    "-D__GLASGOW_HASKELL__=408", "-DHscIfaceFileVersion=5",
                    "-DOMIT_NATIVE_CODEGEN", "-I" + T,
                    "-I" + R + "/build/ghc-4.08.2/ghc/includes",
                    src, "-O" + dst], capture_output=True)
    # cpphs emits {-# LINE #-} pragmas, so mhs reports positions in terms of
    # its *input* -- the unlit output -- not the preprocessed text.
    lines = open(src, errors="replace").read().split("\n")
    for i in range(max(1, line - ctx), min(len(lines), line + ctx) + 1):
        print(("%5d %s" % (i, lines[i - 1]))[:160], "  <==" if i == line else "")


main()
