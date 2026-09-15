# phase4: reproducing the GHC 6.2.2 compiler tree from the pristine tarball

*2026-09-10. Result: one script, `sh phase4/reproduce-6.2.2.sh`, rebuilds
`build/ghc-6.2.2-run1/ghc` from `ghc-6.2.2-src.tar.bz2`. Verified by `diff -r`:
455 files identical except the 28-line prologue of `ghc/includes/config.h`,
which differs in tabs only (explained in section 3). The regenerated module
order is identical; `Util` compiles from the reproduced tree with mhs.*

## 1. Layout: why `phase4/`

README "Layout" gives one directory per stage of the chain and numbers the
4.08.2 patches in a single sequence across phase2 (0001-0024) and phase3
(0019-0030). The 6.2.2 tree is a different tarball, so its series needs its
own numbering, and moving the entry point to 6.2.2 (D45, D46) is a new stage
of the project, not a variant of "building hsc". A separate phase directory
keeps the numbering unambiguous and gives the reproduction script, the
regeneration recipes and this file one home. The 6.2.2 inputs that already
live elsewhere are left where the probe script expects them
(`phase2/hsboot-6.2.2-run1`, `phase2/gen-6.2.2`, `build/shims-6.2.2-run1`);
section 5 records how each was made.

```
phase4/
  reproduce-6.2.2.sh      the one command (section 2)
  patches/                0001-0025, one concern per patch, headers explain the mhs limitation
  series.conf             the series: patch order, headers, hunk classes (section 4)
  split-patch.py          builds patches/ from a working tree (used by make-patch.sh)
  make-patch.sh           regenerates patches/ from build/ghc-6.2.2-run1 (or any tree)
  regen-generated.sh      parsers + primop tables with happy-mhs2 / cpphs / genprimopcode
  genprimopcode-Main.hs.patch   the one edit genprimopcode needs to compile with mhs
  convert-lexer.py        alex -g output -> boxed tables (byte-identical copy of build/lexer622's)
  FINDINGS.md             this file
```

## 2. What `reproduce-6.2.2.sh` does

`sh phase4/reproduce-6.2.2.sh [dest]` (default `build/repro-622`; 3-4 minutes,
of which configure is ~50 s and the mhs build of genprimopcode ~50 s):

| step | what | provenance |
|---|---|---|
| 1 | `tar xjf ghc-6.2.2-src.tar.bz2` into `dest/src`, sha256 checked | section 3 |
| 2 | `patch -p1 -N` with `phase4/patches/*.patch`; any fuzz or offset is an error | section 4 |
| 3 | `./configure --enable-hc-boot --enable-hc-boot-unregisterised --host/--build/--target=x86_64-unknown-linux` with `PATH=/usr/bin:/bin` | `build/rts622/FINDINGS.md` section 1 |
| 4 | `make -C ghc/includes config.h` -- GHC's own `$(H_CONFIG)` rule (platform defines + `mk/config.h`) | section 3 |
| 5 | `gcc -O2 -w -include stdio.h -DNO_REGS -DUSE_MINIINTERPRETER -Ighc/includes -Wl,--unresolved-symbols=ignore-all mkDerivedConstants.c`, run -> `DerivedConstants.h` | `build/ghc-6.2.2-run1/LOG.md`, `build/lexer622/FINDINGS.md` |
| 5b | same recipe on `mkNativeHdr.c`, run -> `NativeDefs.h` (the Makefile builds it unconditionally; `TcForeign.lhs` reaches it through `nativeGen/NCG.h`; cpphs had silently passed the missing include during the probes) | `build/ghc622-stage2/LOG.md` 2026-09-15 |
| 6 | `regen-generated.sh`: `primops.txt` (cpphs), 10 `primop-*.hs-incl` (genprimopcode), `Parser.hs` `ParserCore.hs` `ParsePkgConf.hs` (happy-mhs2, then `fix-generated-parsers.sh`) | `build/gen622/FINDINGS.md` |
| 7 | `convert-lexer.py` on the tarball's `parser/Lexer.hs` | `build/lexer622/FINDINGS.md` |
| 8 | `ln -s ../../utils/ghc-pkg ghc/compiler/utils/ghc-pkg` | `build/ghc-6.2.2-run1/FINDINGS.md` section 1 |
| 9 | assemble `dest/ghc/{compiler,includes,utils/ghc-pkg}`; regenerate `dest/order-6.2.2.txt` with `phase2/build-order.py` minus `ilxGen/tests` | section 5 |
| 10 | `diff -r` against `build/ghc-6.2.2-run1/ghc` (excluding `tmp`, `.mhscache*`, `*.log`, `*.rej`, `*.orig`, `*.o`, `*.comb`) | section 3 |

The full extraction stays in `dest/src/ghc-6.2.2` (patched, configured): the
RTS work in `build/rts622` starts from the same tree, so a later phase can
build on it. `dest/ghc` has exactly the shape the probe script consumes:

```sh
TMPDIR=build/repro-622/tmp EXTRA_SHIMS=$PWD/build/shims-6.2.2-run1 \
  sh build/probe-ordered-622.sh repro build/repro-622/ghc/compiler \
     build/repro-622/ghc/includes build/repro-622/order-6.2.2.txt \
     phase2/hsboot-6.2.2-run1 phase2/gen-6.2.2
```

## 3. Verification

`diff -r build/repro-622/ghc build/ghc-6.2.2-run1/ghc` (the exclusions above):
**one file differs, `ghc/includes/config.h`, and only in whitespace**
(`diff -w`: identical). 455 files on each side; the symlink has the same
target. `build/repro-622/log/verify.diff` holds the diff.

The difference: run1's `config.h` is the copy `build/rts622` made by
transcribing the Makefile's `$(H_CONFIG)` rule by hand, with one tab per
define; the rule itself (`ghc/includes/Makefile:39-76`) emits its 28-line
prologue with the tab runs written in the Makefile (`_HOST\t\t1`,
`_BUILD  \t1`, `HOST_OS \t\t\t\t"linux"`, ...). The 1,119-line body
(`mk/config.h`, configure's output) is byte-identical, as it was in
`build/rts622`. The script keeps the Makefile's output: it is what GHC's own
build writes, the prologue is `#define`s whose internal whitespace cpp
ignores, and a transcription that imitates the tabs of another transcription
would document nothing. The README text below says "identical up to the tabs
in config.h's prologue" rather than "byte for byte".

Also checked:

- **Module order.** `phase2/build-order.py` over the reproduced tree, minus the
  31 programs under `ilxGen/tests` (they are not compiler modules; `build/
  ghc-6.2.2-run1/FINDINGS.md` removed them by name), gives 235 modules
  identical to `build/order-6.2.2.txt`. The full 266-entry output equals
  `build/rebase622/build-order-6.2.2.txt`.
- **Headers regenerate.** `configure` on a fresh extraction gives an
  `mk/config.h` identical to `build/rts622`'s; the DerivedConstants recipe
  gives a file identical to run1's (`STD_ITBL_SIZE 3`; without the two
  unregisterised defines it is 2, which is what `build/lexer622/includes`
  has).
- **Generated sources regenerate.** The 14 happy/genprimopcode outputs and the
  converted `Lexer.hs` are byte-identical to run1's (they are outside the
  patch series, so the `diff -r` is the check). Since 2026-09-15 the three
  happy outputs pass through `fix-generated-parsers.sh` first: three rewrites
  of happy 1.19.5 template habits that GHC 6.2.2 rejects (`OPTIONS_GHC`, the
  `Control.Applicative`/`Control.Monad (ap)` imports, and the parenthesised
  monad `(P) HappyAbsSyn` in the signature block, which 6.2.2 cannot unify
  when `P` is a function-type synonym, as in ParserCore). The run1 copies
  carry the same rewrites, so the check still holds; the script's header has
  the details (`build/ghc622-stage2/LOG.md`, 2026-09-15).
- **Series self-check.** `make-patch.sh` applies the freshly written series to
  a clean copy and diffs it against the tree: 25 patches, 249 hunks, 101
  files, no fuzz, no offset, identical.
- **Smoke test.** `Util` (row 7 of the order) compiled from the reproduced tree
  with the probe script's exact mhs flags into `build/repro-622/smoke/`
  (`.mhscache` 636 KB): rc 0, 54 s cold (`smoke-Util.log`). The full ordered
  pass (about an hour) was not rerun; the byte-level identity of the tree is
  the evidence that it would give D46's result.

A note on method: an exploratory configure run made while writing this
(`build/repro-622/conf-test`, since removed) found the machine's GHC on PATH
and recorded it as the booter (`GhcVersion 9.12.2` in `mk/config.mk`,
`cBooterVersion "9.12.2"` in a `make main/Config.hs` output). `mk/config.h`
was unaffected, but this is why the script runs configure and make with
`PATH=/usr/bin:/bin`. Background runs of the script were killed once by the
system for lack of memory while another agent was linking; the recorded run
(`build/repro-622/log-run3.txt`) is a foreground run.

## 4. The patch series

`phase4/patches/0001-0025`, 249 hunks over 101 files under `ghc/compiler`,
each with a header naming the mhs limitation. Everything else in the tree is
generated (section 2) or pristine. Same content as `build/6.2.2-run1.patch`
(187 three-line-context hunks), split by concern:

| patch | hunks | files | concern |
|---|---:|---:|---|
| 0001-unlit-trailing-space | 26 | 21 | blanks after `\begin{code}`/`\end{code}` (mhs unlit) |
| 0002-slit-boxed-string-literals | 13 | 2 | `SLIT`/`FSLIT` over boxed `String`; Pretty's `LStr` path; hide `(<>)`,`(<$>)` |
| 0003-machdeps-include-path | 2 | 2 | `#include "../includes/MachDeps.h"` (MicroHs ships its own MachDeps.h) |
| 0004-binary-portable-serialisation | 15 | 1 | `Binary.hs` without ByteArray#, `S#`/`J#`, `:%` |
| 0005-unique-portable-base62 | 4 | 1 | `iToBase62` without `indexCharOffAddr#` |
| 0006-uniqsupply-haskell-gensym | 5 | 1 | `mk_supply#` CAF -> parameter; `genSym` from GhcCompat |
| 0007-unboxed-char-literals | 2 | 1 | `'\xc0'#` -> `'\xc0'` |
| 0008-ctype-latin1-to-utf8 | 1 | 1 | Ctype.lhs comments transcoded |
| 0009-drop-scc-annotations | 42 | 10 | `_scc_` |
| 0010-do-block-empty-statements | 10 | 5 | `do { ; ...` |
| 0011-trailing-and-double-commas | 17 | 9 | `,,` and trailing commas |
| 0012-duplicate-import-items | 21 | 18 | items listed twice |
| 0013-abstract-type-import-items | 9 | 9 | `T(..)` vs abstract exports with named fields |
| 0014-applicative-monad-instances | 13 | 7 | Functor/Applicative/MonadFail |
| 0015-space-around-composition-dot | 35 | 24 | `f.g` -> `f . g` (record dot) |
| 0016-hide-semigroup-op | 2 | 2 | `import Prelude hiding ((<>))` where HsVersions.h is absent |
| 0017-foreign-import-syntax | 14 | 13 | pre-addendum `foreign import`/`foreign label` |
| 0018-pprabsc-float-bit-casts | 3 | 1 | `castSTUArray` -> GhcCompat casts |
| 0019-simplmonad-portable-array-index | 3 | 1 | `indexArray#` -> `(!)` |
| 0020-bytecodeitbls-ptr-to-int | 2 | 1 | `addr2Int#` -> `ptrToIntPtr` |
| 0021-panic-drop-typeable-instance | 1 | 1 | hand-written `Typeable` |
| 0022-fused-signature-bindings | 4 | 4 | `f :: T = e` split |
| 0023-systools-ghc-version-guard | 1 | 1 | `#error GHC >= 5.00` not under `__MHS__` |
| 0024-tcsplice-non-ghci-stubs | 3 | 1 | guard `compileExpr` import, stub `tcBracket` |
| 0025-srcloc-strict-fields | 1 | 1 | `!FastInt` line/column |

Header conventions: the 4.08.2 patches carry their explanation as `-- mhs`
comments inside the diff and in `PATCHES.md`; these do that too (the inline
comments came with the edits) and additionally start with a header paragraph,
which `patch(1)` ignores. Three impurities are stated in the headers rather
than hidden: in `HscMain` some `_scc_` lines also lost a leading `;` (0009
takes the line); three import lists needed both a duplicate removed and a
field named (0012 takes them); a handful of `.`-spacing and comma edits fell
in comments or Java text and are kept for byte fidelity (0011, 0013, 0015).

### Regenerating the series (`make-patch.sh`)

`build/ghc-6.2.2-run1` is another agent's working tree and may gain edits;
the series is derived from it, never the other way round:

```sh
sh phase4/make-patch.sh [tree]        # default build/ghc-6.2.2-run1; tree is read only
```

It extracts a fresh pristine copy, runs `split-patch.py`, then applies the
new series to a second clean copy and diffs it against the tree. The
exclusion list is the one `build/6.2.2-run1.patch` used (`primop-*.hs-incl`,
`primops.txt`, the three happy outputs, `Lexer.hs`, `tmp`, the `ghc-pkg`
symlink). `split-patch.py`:

1. takes `diff -rN -U0` (zero context, pristine line numbers) of `ghc/compiler`;
2. classifies every hunk: `series.conf`'s manifest (`hunk FILE@LINE CLASS`)
   first, then heuristics for the mechanical classes (whitespace-only,
   `_scc_`, `foreign import`, leading `;`, `f.g`, one comma fewer,
   new Functor/Applicative/MonadFail instances, `hiding ((<>))`, an import
   item removed / added / opened). A hunk nobody claims stops the run and is
   printed with its `FILE@LINE`, so a new edit in the tree either
   auto-classifies or asks for one manifest line;
3. materialises stage k of every file (hunks of patches 1..k, applied
   bottom-up), writes patch k as `diff -u` of stage k-1 vs k -- hence exact
   line numbers -- and checks that the last stage equals the tree byte for byte.

Manifest keys are pristine line numbers, which do not move when the tree is
edited; a new edit adjacent to an old hunk merges with it under `-U0` and
shows up as an unclassified hunk, which is the intended failure.

## 5. Inputs that are not in the tree, and where each came from

**`ghc-6.2.2-src.tar.bz2`** -- repo root, next to `ghc-4.08.2-src.tar.bz2`.
5,406,427 bytes, sha256
`a0fe7eb8d447f25fbc616cdbce2bb4e03961a884c2c37969d1e23588b588a852`
(the script checks it). Fetched 2026-09-09 (file mtime) for `build/rts622`;
the repo does not record the URL. GHC's release archive publishes it at
`https://downloads.haskell.org/~ghc/6.2.2/ghc-6.2.2-src.tar.bz2`. The
extractions in `build/rts622/ghc-6.2.2`, `build/rebase622/ghc-6.2.2` and
`build/ghc-6.2.2` were all made from it; the script never reads them.

**Tools from earlier in the chain** (all built without GHC): `MicroHs/bin/mhs`
and `MicroHs/bin/cpphs` (phase0/phase1), `build/happy-mhs/happy-mhs2` with
`build/happy-mhs/datadir` (the fixpoint-verified happy, `phase2/FINDINGS.md`),
`phase1/shims-h98` (for genprimopcode), system `gcc`, `make`, `patch`,
`python3`. `genprimopcode` is compiled during the run from the tarball's own
`ghc/utils/genprimopcode/Main.hs` plus `genprimopcode-Main.hs.patch` (one
`not.dodgy` -> `not . dodgy`) and the Parsec slice shim
`build/shims-6.2.2-run1/Parsec.hs`.

**`ghc/includes/config.h`** -- configure + the `$(H_CONFIG)` rule (section 3).

**`ghc/includes/DerivedConstants.h`** -- `mkDerivedConstants.c` with the RTS's
unregisterised defines. `ghc/includes/Makefile` would pass them through
`mk/bootstrap.mk`; the recipe passes them by hand.

**`parser/Lexer.hs`** -- the tarball ships alex 2.0's `-g` output, so no alex is
needed; `convert-lexer.py` (identical to `build/lexer622/convert-lexer.py`,
`cmp` clean) decodes the four `Addr#` tables into boxed arrays and asserts
every line it touches against the pristine text.

**`ghc/utils/ghc-pkg`** -- pristine (7 files, unedited); `main/Packages.lhs`
`#include`s `../utils/ghc-pkg/Package.hs`, hence the symlink.

**`build/shims-6.2.2-run1`** (not produced by the script; the probe's
`EXTRA_SHIMS`): `build/shims-6.0-run2` plus `CForeign.hs` (re-exports
Foreign.C; SysTools' `< 603` branch), `Foreign.hs` (PrelForeign + Foreign.Ptr/
Marshal.Utils/Marshal.Array/Storable; shadows `phase1/shims-ghc/Foreign.hs`),
`StringBuffer.hs` (the 118-line shim for 6.2.2's 11-function API, identical to
`build/lexer622/StringBuffer.hs`), and `Language/Haskell/THSyntax.hs` =
6.2.2's `libraries/haskell-src/Language/Haskell/THSyntax.hs` with four edits
(`import Prelude hiding ((<>))`; `MonadIO` from `Control.Monad.IO.Class`
instead of `Control.Monad.Trans`; `Functor`/`Applicative Q`; `MonadFail Q`);
the 6.0 version is kept beside it as `THSyntax.hs.60`. `diff -r` against
`shims-6.0-run2` shows exactly these four entries.

**`phase2/hsboot-6.2.2-run1`** (32 files): `phase2/hsboot-6.0-run2` with two
edits, both from 6.2.2's own `.hi-boot-6` files: `TcMatches.hs-boot`
(`tcGRHSs :: HsMatchContext Name -> RenamedGRHSs -> ...` became
`tcGRHSsPat :: RenamedGRHSs -> ...`) and `DataCon.hs-boot` (adds
`dataConInstOrigArgTys :: DataCon -> [Type] -> [Type]` and its `SOURCE`
import of TypeRep). The 6.0 set was hand-converted from `.hi-boot-6`
(`phase2/hiboot2hsboot.py` reads the GHC-4 flavour); 30 of 32 carry over
verbatim (`build/rebase622/FINDINGS.md` section 4).

**`phase2/gen-6.2.2/Config.hs`**: the `$(CONFIG_HS)` rule of
`ghc/compiler/Makefile:180-227` transcribed, i.e. `phase2/gen-6.0/Config.hs`
with `cProjectVersion "6.2.2"`, `cProjectVersionInt "602"`,
`cProjectPatchLevel "2"` (`ghc/mk/version.mk:39-41`); the other 33 fields
are unchanged. It is a transcription with chosen values, not configure
output: `make -C ghc/compiler main/Config.hs` in the configured tree emits the
same 36 fields but with `cGhcUnregisterised "NO"` (that flag lives in
`mk/build.mk`, which we do not write), the utility dirs filled in
(`cGHC_UNLIT_DIR_REL "utils/unlit"`, ...), `cGHC_PERL "/usr/bin/perl"`,
`cCONTEXT_DIFF "diff -C 1"`, `cEnableWin32DLLs ""` and whatever booter
configure saw. None of those is read on the path the probe exercises; the
checked-in file states an unregisterised x86-64 build, which is what the tree
is configured for.

**`build/order-6.2.2.txt`**: `phase2/build-order.py ghc/compiler` minus the
`ilxGen/tests` programs; the script regenerates it (`dest/order-6.2.2.txt`)
and reports whether it matches -- it does.

**`build/probe-ordered-622.sh`**: the driver; its cpp defines
(`__GLASGOW_HASKELL__=408`, no `GHCI`, `OMIT_NATIVE_CODEGEN`) are documented
in its header and in `build/ghc-6.2.2-run1/FINDINGS.md` section 1.

## 6. Proposed README text

For "Reproducing", after the 4.08.2 block:

```
### GHC 6.2.2 (the current entry point, D45/D46)

    sh phase4/reproduce-6.2.2.sh            # -> build/repro-622/ghc

One script, from the pristine ghc-6.2.2-src.tar.bz2 (sha256 a0fe7eb8...852):
25 patches (phase4/patches, one concern each), GHC's own configure and
config.h rule, DerivedConstants.h from mkDerivedConstants.c with the
unregisterised flags, the three parsers and ten primop tables regenerated with
our happy and an mhs-built genprimopcode, and the alex lexer's Addr# tables
decoded into boxed arrays. The result is checked against the working tree by
diff -r: identical up to the tabs in config.h's 28-line prologue. The series
is derived from the working tree, not the other way round:
`sh phase4/make-patch.sh` regenerates it and fails on any hunk it cannot
classify. Then:

    TMPDIR=build/repro-622/tmp EXTRA_SHIMS=$PWD/build/shims-6.2.2-run1 \
      sh build/probe-ordered-622.sh <label> build/repro-622/ghc/compiler \
         build/repro-622/ghc/includes build/repro-622/order-6.2.2.txt \
         phase2/hsboot-6.2.2-run1 phase2/gen-6.2.2
```

For "Layout", after the phase3 lines:

```
phase4/               GHC 6.2.2, the entry point since D45: reproduce-6.2.2.sh,
                      patches 0001-0025, the regeneration recipes; FINDINGS.md
                      records the provenance of every non-patch input
```

and `DECISIONS.md          the decision log, D1-D46`.

## 7. Addendum, 2026-09-10 evening: patch 0026 and the HTYPE step

After the compiler was linked and run (DECISIONS.md D47, D48) the tree gained
eight hunks in four files (`utils/Binary.hs`, `basicTypes/Literal.lhs`,
`coreSyn/CoreUtils.lhs`, `main/DriverUtil.hs`): arithmetic that must wrap,
`hFileSize`, and `exitWith`. `make-patch.sh` refused them as unclassified, as
designed; they are now class `RUNTIME`, patch
`0026-runtime-wraps-and-driver-exit`. The series is **26 patches, 257 hunks,
102 files**, and `make-patch.sh` reports "series applies exactly and
reproduces" the tree.

`ghc/includes/config.h` also gained 34 `HTYPE_*` defines: configure's
`FPTOOLS_CHECK_HTYPE` probes are K&R C that gcc 16 rejects, so the rule's
output left them `#undef`. `reproduce-6.2.2.sh` now compiles and runs
`phase4/gen-htypes.c` (a copy of `build/ghc622-mhs/gen-htypes.c`) and appends
its output after the DerivedConstants step. The counts "25 patches / 249
hunks / 101 files" earlier in this file describe the series before this
addendum.

Not in the series, by design: the FastString shim fix (`intern` forces its
argument before touching the table; `build/shims-6.2.2-run1/FastString.hs`
and `phase1/shims-ghc/FastString.hs`, patch in
`build/ghc622-mhs/diag/faststring-intern.patch`) lives in the shims, which are
inputs to the build rather than part of the pristine tree.

## 8. Addendum, 2026-09-15: the series is one hunk behind the tree

During stage 2 (DECISIONS.md D49, `build/ghc622-stage2/LOG.md`)
`build/ghc-6.2.2-run1/ghc/compiler/main/GetImports.hs` gained an
`#if defined(__MHS__)` branch (11 added lines, `-- mhs` comment): the driver
reads a module's source through a text-mode handle to find its imports, and
under the MicroHs runtime that decodes UTF-8 and dies on the Latin-1
`parser/Ctype.lhs`; the branch reads bytes with `readBinaryFile`, as
`readBinMem` in `utils/Binary.hs` already does. The edit is in the tree and
in neither `phase4/patches` nor `series.conf`, so `make-patch.sh` will stop
on it as unclassified, which is the designed failure. It belongs with 0026
(class `RUNTIME`) or as a 0027 of its own. `build/6.2.2-run1.patch` (08:12)
and the linked `build/ghc622-mhs/ghc` (10:04) both predate the edit (11:43).

`reproduce-6.2.2.sh` was also reordered after section 7 was written: the
`HTYPE_*` step now runs after the parser regeneration (log-run6), which
changes nothing in the output. Run 6 is the recorded run: 235 modules,
order identical, `config.h` whitespace-insensitively identical, one
whitespace diff in `verify.diff`.
