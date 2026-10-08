#!/usr/bin/env python3
"""Translate GHC 4.08.2's .hi-boot files into .hs-boot files for mhs.

GHC breaks its module cycles with .hi-boot files -- a textual dump of *its own*
interface format, not Haskell. mhs breaks the same cycles with .hs-boot files,
which are ordinary Haskell modules holding signatures. The information is the
same; only the notation differs, and the notation is regular enough to convert:

    _interface_ TyCon 1              ->  module TyCon where
    _exports_                            import Name
    TyCon TyCon isFunTyCon ;             data TyCon
    _declarations_                       isFunTyCon :: TyCon -> Bool
    1 data TyCon;
    1 isFunTyCon _:_ TyCon -> PrelBase.Bool ;;

Output goes to a side directory on mhs's -i path, so the tarball stays pristine
(DECISIONS.md D11).

    notes/phase2/hiboot2hsboot.py <compiler-tree> <output-dir>
"""
import re, sys, os

# GHC 4.08's internal names for what is now just the Prelude.
PRELUDE_MODULES = {"PrelBase", "PrelNum", "PrelShow", "PrelMaybe", "PrelList",
                   "PrelGHC", "PrelRead", "PrelIOBase"}

DECL = re.compile(r"^\d+\s+", re.M)
QUALIFIED = re.compile(r"\b([A-Z][A-Za-z0-9_']*)\.")


def convert_type(t):
    """.hi-boot type notation -> Haskell.

    The notation has three shapes worth knowing:
        _:_                     ::
        _forall_ [i p]          forall i p .        (sometimes followed by a
                                                     bare "=>" with no context)
        {C a}  ->  or  {C a} => (C a) =>            class contexts are braced,
                                                     and the arrow after them is
                                                     written either way
    """
    t = t.replace("_:_", "::")
    t = re.sub(r"_forall_\s*\[([^\]]*)\]", lambda m: "forall " + m.group(1).strip() + " .", t)
    # a forall with no context is still written "=> " in some files
    t = re.sub(r"\.\s*=>", ".", t)
    # {Ctx} followed by either arrow is a class context
    t = re.sub(r"\{([^}]*)\}\s*(?:=>|->)", lambda m: "(" + m.group(1).strip() + ") =>", t)
    for m in PRELUDE_MODULES:                     # PrelBase.Bool -> Bool
        t = t.replace(m + ".", "")
    return " ".join(t.split())


# Modules we hand-write a .hs-boot for in notes/phase2/hsboot/ because GHC needed no
# .hi-boot for them -- its boot files are interfaces and do not create build
# edges, while mhs's are real modules.
#
#   Type      PprType.hs-boot names Type.PredType
#   InstEnv   its .hi-boot says `data`, the real module says `type` (and the
#             synonym's free names need imports this script cannot infer)
#   DsUtils   Match.hs-boot names its types, and DsUtils SOURCE-imports Match
#   CgMonad   CgUsages.hs-boot names FCode, and CgMonad SOURCE-imports CgUsages
#
# The last two are the general shape: a boot file must SOURCE-import anything
# that imports *it*, which requires that module to have a boot file too.
EXTRA_BOOT = {"Type", "InstEnv", "DsUtils", "CgMonad"}

BOOT_MODULES = set(EXTRA_BOOT)   # completed by main, before any conversion
REAL_SOURCE = {}                 # module name -> path of the real .hs/.lhs


def real_type_synonyms(mod):
    """`type X = ...` definitions in the real module, by name.

    A .hi-boot can declare `data X` for something the real module defines as a
    type synonym -- GHC reconciles the two when it reads the real interface,
    mhs does not, and the mismatch surfaces far away as
    `InstEnv ~ [(UniqFM Var, [Type], Var)]`. So emit the synonym instead.
    """
    path = REAL_SOURCE.get(mod)
    if not path:
        return {}
    syns = {}
    for line in open(path, encoding='utf-8', errors='replace'):
        m = re.match(r"\s*type\s+([A-Z][\w']*)\s*((?:[a-z][\w']*\s*)*)=\s*(.+)", line)
        if m:
            syns[m.group(1)] = (m.group(2).strip(), m.group(3).strip().rstrip(";"))
    return syns


def convert(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(r"_interface_\s+(\S+)", text)
    if not m:
        return None, None
    name = m.group(1)

    syns = real_type_synonyms(name)
    body = text.split("_declarations_", 1)
    if len(body) < 2:
        return name, "module %s where\n" % name
    decls, out = body[1], []
    for entry in DECL.split(decls):
        entry = entry.strip()
        if not entry:
            continue
        entry = entry.rstrip(";").strip()
        if entry.startswith(("data ", "newtype ", "type ", "class ")):
            m = re.match(r"data\s+([A-Z][\w']*)\s*$", entry)
            if m and m.group(1) in syns:
                args, rhs = syns[m.group(1)]
                entry = "type %s %s = %s" % (m.group(1), args, rhs)
            out.append(convert_type(entry))
        elif "_:_" in entry:
            out.append(convert_type(entry))

    # a .hi-boot qualifies references to the module's own names; strip that,
    # since the module cannot import itself
    out = [d.replace(name + ".", "") for d in out]

    # every other module mentioned in a signature has to be imported for mhs
    # to resolve the qualified name
    mods = {q for d in out for q in QUALIFIED.findall(d)}
    mods -= {name}
    mods = sorted(m for m in mods if m not in PRELUDE_MODULES)

    lines = ["module %s where" % name]
    # A .hi-boot is an interface, so GHC resolves the names in it without
    # creating a build edge. A .hs-boot is a real module, so a plain import of
    # another boot module re-creates the very cycle the boot file exists to
    # break (Name -SOURCE-> Var -> Name). Import boot modules with {-# SOURCE #-}.
    lines += ["import %s%s" % ("{-# SOURCE #-} " if m in BOOT_MODULES else "", m)
              for m in mods]
    lines.append("")
    lines += out
    return name, "\n".join(lines) + "\n"


if __name__ == "__main__":
    tree, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    # first pass: which modules have a boot file at all
    for dp, _, files in os.walk(tree):
        for f in files:
            if f.endswith(".hi-boot"):
                BOOT_MODULES.add(f[:-len(".hi-boot")])
            elif f.endswith((".hs", ".lhs")):
                REAL_SOURCE.setdefault(os.path.splitext(f)[0], os.path.join(dp, f))
    n = 0
    for dp, _, files in os.walk(tree):
        for f in sorted(files):
            if not f.endswith(".hi-boot"):
                continue
            name, src = convert(os.path.join(dp, f))
            if src is None:
                print("  SKIP  %s" % f); continue
            open(os.path.join(outdir, name + ".hs-boot"), "w").write(src)
            n += 1
    print("wrote %d .hs-boot files to %s" % (n, outdir))
