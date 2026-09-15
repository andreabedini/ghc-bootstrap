# Bootstrapping GHC from source

Building a Haskell compiler on a machine that has no Haskell compiler, starting
from a C compiler and nothing else.

The chain, each link built from source by the link before it:

```
C compiler + Hugs source
   -> mhs                    (MicroHs, compiled by Hugs)
   -> cpphs, happy, hsc2hs   (compiled by mhs)
   -> ghc                    (GHC 6.2.2's compiler proper, compiled by mhs)
   -> .hc                    (Abstract C for base and a test program)
   -> gcc -> ld              (with 6.2.2's own RTS, unregisterised x86-64)
   -> an executable that runs and prints "hello"
```

The only pre-existing binary anywhere in this is a C compiler. The first
attempt used GHC 4.08.2 as the compiler rung and stopped at a 64-bit runtime
bug (D42); 6.2.2 is the first GHC that knows x86-64 exists, and the same
chain goes all the way through with it (D45–D48).

The next rung, GHC 6.2.2 compiling itself into a native binary, is started
and not finished (D49, `build/ghc622-stage2/LOG.md`).

## What works

**GHC 6.2.2** (the current line of work; see DECISIONS.md D45-D49 and
`build/ghc622-mhs/FINDINGS.md`, `FINDINGS-link.md`):

| Stage | Result |
|---|---|
| 6.2.2's compiler proper, typechecked by mhs | 226/235 modules, `Main` included |
| ... linked by mhs + gcc | a 2.9MB `ghc` that answers `--version` |
| `libraries/base` compiled by it | 147/147 modules to `.hi` + `.hc` |
| those `.hc` compiled by gcc | 147/147 `.o` (`-fwrapv` is mandatory) |
| `ghc/rts` unregisterised x86-64 | 78/78 objects, `libHSrts.a` |
| base cbits, `hsc2hs` (built with mhs), `libHSbase.a` | built, no patches |
| Link of a Haskell program | zero undefined symbols |
| **Run** | **`putStrLn "hello"` prints and exits 0**; GC, Integer, Double, I/O, exceptions, `forkIO`, arrays, time/dir/random/regex all pass |
| `libraries/haskell98` compiled by it | 30/30 to `.o`, `libHShaskell98.a` |
| **Stage 2**: 6.2.2's compiler proper compiled by the mhs-built `ghc` | **in progress**: 80 of 220 modules to `.hc`, the first 16 to `.o`; run interrupted 2026-09-10, resumable |

**GHC 4.08.2** (the first chain, DECISIONS.md D1-D42; retired, kept as the
record of why the entry point moved):

| Stage | Result |
|---|---|
| `hsc`, GHC 4.08.2's compiler proper | builds and runs (2.2MB) |
| `ghc/lib/std` — the Prelude | 45/45 modules to object code |
| `hslibs/lang` | 24/24 modules to object code |
| `ghc/rts` — the runtime | 52/52 (45 C + 7 hand-written Abstract C) |
| `cbits` | 42/42 |
| Link | 6MB executable |
| **Run** | **`main = return ()` runs and exits 0** |

On 4.08.2 a program that does I/O does not work: it reaches the buffering
setup for `stdout` and dies on a 64-bit assumption in the 1999 runtime
(D42). That is the bug 6.2.2 does not have.

## Reproducing

Sources are pristine tarballs plus patches — nothing is edited in place, and the
invariant is checked, not assumed.

The scripts under `build/` and `phase0`–`phase3` find the checkout through
`GHC_BOOTSTRAP_ROOT`, which `mise.toml` sets to the repository root. Run them
under mise (`mise activate` in the shell, or `mise exec -- sh build/...`);
without it they stop at once with `GHC_BOOTSTRAP_ROOT: not set`. The
`phase4` scripts are relative to the working directory and need nothing.

### GHC 6.2.2, the current entry point (D45–D48)

The compiler tree, from the pristine `ghc-6.2.2-src.tar.bz2`:

```sh
sh phase4/reproduce-6.2.2.sh            # -> build/repro-622/ghc, 3-4 minutes
```

One script: 26 patches (`phase4/patches`, one concern each), GHC's own
configure and `config.h` rule, `DerivedConstants.h` from
`mkDerivedConstants.c` with the unregisterised flags, the `HTYPE_*` block
that gcc 16 stops configure from producing, the three parsers and ten primop
tables regenerated with our happy and an mhs-built genprimopcode, and the
alex lexer's `Addr#` tables decoded into boxed arrays. The result is checked
against the working tree with `diff -r`: identical up to the tabs in
`config.h`'s 28-line prologue. The series is derived from the working tree,
not the other way round: `sh phase4/make-patch.sh` regenerates it and fails
on any hunk it cannot classify. `phase4/FINDINGS.md` records the provenance
of every input, including the ones the script does not produce (the shims,
the boot files, `Config.hs`).

Typechecking the tree with mhs (about an hour; `phase4/FINDINGS.md` section 2):

```sh
TMPDIR=build/repro-622/tmp EXTRA_SHIMS=$PWD/build/shims-6.2.2-run1 \
  sh build/probe-ordered-622.sh <label> build/repro-622/ghc/compiler \
     build/repro-622/ghc/includes build/repro-622/order-6.2.2.txt \
     phase2/hsboot-6.2.2-run1 phase2/gen-6.2.2
```

From the typechecked tree to a running program, the steps live under
`build/` and are not yet folded into `phase4/` (each directory's
`FINDINGS.md` gives the exact invocation and flags):

| step | where | script |
|---|---|---|
| RTS, unregisterised x86-64 (two patches, 78 objects) | `build/rts622` | `build-rts.sh` |
| link the compiler proper with mhs (`.comb` -> C -> `ghc`, ~10 min) | `build/ghc622-mhs` | `build.sh comb && build.sh c && build.sh cc` |
| `hsc2hs` with mhs, the four `.hsc` modules of base | `build/hsc2hs-mhs` | `build.sh`, then `hsc2hs` per module |
| compile `libraries/base` to `.hi` + `.hc` | `build/ghc622-mhs` | `run-base.sh` (retries `-O -fno-strictness` on demand-analyser blow-ups) |
| `.hc` -> `.o` (`-fwrapv -std=gnu89`) | `build/ghc622-mhs` | `build-hc.sh` |
| cbits, `libHSbase.a` | `build/ghc622-mhs` | `build-cbits.sh`, `build-libbase.sh` |
| compile, link and run a program | `build/ghc622-mhs` | `sh link.sh test/Hello.hs` |
| `libraries/haskell98`, stage 2 of the compiler | `build/ghc622-stage2` | `build-haskell98.sh`, `run-compiler.sh` |

### GHC 4.08.2 (retired chain, D1–D42)

```sh
tar xjf ghc-4.08.2-src.tar.bz2 -C <dir>
cd <dir>/ghc-4.08.2
for p in phase2/patches/*.patch phase3/patches/*.patch; do patch -p1 -i "$p"; done
```

30 patches. Applying them to a clean extraction reproduces the working tree
byte for byte. Then:

```sh
phase2/mkconfig.sh              # runs GHC's own configure, writes ghc/includes/config.h
build/compile-ghc.sh            # build hsc with mhs
phase3/build-prelude.sh         # ghc/lib/std      -> .hi .hc .o
phase3/build-hslibs-lang.sh     # hslibs/lang      -> .hi .hc .o
phase3/build-rts.sh             # ghc/rts          -> .o
phase3/build-cbits.sh           # cbits            -> .o
```

## Layout

```
DECISIONS.md          the decision log, D1-D49: every choice and every wrong turn
BOOTSTRAP-ANALYSIS.md why this chain, and why not a shorter one (2026-09-02, with status notes)
PATCHES.md            the two patch series, grouped by what each patch is really about
phase0/               surveying candidate compilers; the Hugs -> MicroHs seed (feature-scan.py)
phase1/               ghc-on-mhs: shims, import inventory, happy analysis
phase2/               building hsc: patches 0001-0024, build order, cpp pipeline;
                      also the 6.2.2 boot files (hsboot-6.2.2-run1) and Config (gen-6.2.2)
phase3/               building the 4.08.2 libraries and runtime: patches 0019-0030
  patches/            source changes, one concern per patch
  build-*.sh          the build steps
  FINDINGS.md         what each phase established
phase4/               GHC 6.2.2, the entry point since D45: reproduce-6.2.2.sh,
                      patches 0001-0026, the regeneration recipes; FINDINGS.md
                      records the provenance of every non-patch input
build/                everything built, plus the 6.2.2 work not yet folded into phase4:
  ghc-6.2.2-run1/     the compiler tree mhs typechecks (the reference reproduce-6.2.2.sh diffs against)
  shims-6.2.2-run1/   the ghc-on-mhs shims the 6.2.2 build uses
  gen622/ lexer622/   regenerated parsers and primop tables; the alex lexer conversion
  rts622/             6.2.2's RTS on x86-64, libHSrts.a
  ghc622-mhs/         the mhs-built ghc, base, cbits, libHSbase.a, link.sh, the 12 test programs
  hsc2hs-mhs/         hsc2hs built with mhs
  ghc622-stage2/      stage 2: the mhs-built ghc compiling its own source (in progress)
  repro-622/          the output of reproduce-6.2.2.sh
  rebase622/ research-6.2-x86_64.md   the measurements behind D45
```

## What does not work, precisely

On the 6.2.2 chain, as of 2026-09-15:

1. **Stage 2 is unfinished.** The mhs-built `ghc` compiling its own source
   got 80 of 220 modules to `.hc` (the first 16 to `.o`) before the run was
   interrupted with the session on 2026-09-10; nothing has been linked. The
   four recorded failures are fixed in the tree and wait for a `FRESH=0`
   resume (`build/ghc622-stage2/LOG.md`). Under 6.2.2's own base, three
   things the mhs probe never saw: the compiler reads Latin-1 `Ctype.lhs`
   through a text handle, and our happy's `OPTIONS_GHC` pragma and
   `Control.Applicative` import are unknown to a 2004 base.
2. **The patch series is one edit behind the tree.** `GetImports.hs` gained
   an `__MHS__` branch during stage 2; it is in `build/ghc-6.2.2-run1` but
   not in `phase4/patches`, and the linked `build/ghc622-mhs/ghc` predates it.
   `sh phase4/make-patch.sh` will refuse the hunk until `series.conf` names
   it; then relink.
3. **Nine compiler modules do not typecheck under mhs**, none on `Main`'s
   path: `PrimPacked` (shadowed by the FastString shim), five GHCi bytecode
   modules plus `InteractiveUI` (`GHC.Ptr`; GHCI is off), and the dead
   `IlxGen` and `JavaGen` back ends.
4. **Known 6.2.2 limits on x86-64** (`build/research-6.2-x86_64.md`):
   `HEAP_ALLOCED` uses the low 32 bits of an address, so a program that
   allocates more than 4 GB of address space can misbehave (the fix is one
   6.4 commit); `foreign import "wrapper"` adjustors are not supported.
5. **Hygiene left over from D48.** The RTS was compiled without `-fwrapv`
   (no failure traced to it); the 4.08.2 `hsc` was never relinked with the
   fixed FastString shim; `phase1/shims-ghc` and `build/shims-6.2.2-run1`
   are two copies of the same shims.

The 4.08.2 chain stopped at D42: GHC 4.08.2 targets 32-bit machines and has
no entry for x86-64 at all, so wherever "32-bit" and "correct" happened to
coincide the code is silently wrong and nothing selects a working
alternative. Six such bugs were fixed (D30, D31, D36, D42); the seventh,
execution jumping into `PrelHandle_getBModezuzu_info` instead of its entry
code, is where it was left. Finishing it would be a port of the 1999 runtime
to a word size it was never written for, which is why the entry point moved.

## The thing most worth knowing

`hsc` is not a compiler you can invoke. It is the middle of a pipeline whose two
ends were written in perl, and eight separate responsibilities had to be
reconstructed before it would produce a working library:

1. `unlit` — literate Haskell, dispatched on the `.lhs` suffix
2. cpp, with the driver's exact five `-D` flags
3. `ghc-iface.lprl` — `hsc` writes only a *partial* interface
4. the shipped `PrelGHC.hi` — the primop interface is not compiled
5. `-fsimplify [ -fmax-simplifier-iterations4 ]` — never omitted, even at `-O0`
6. `{-# OPTIONS #-}` extraction — `hsc` does not read pragmas
7. `-package-name std` — which the driver *renames* to `-inpackage=std`
8. `-static` — without it the code generator emits `DLL_SRT_ENTRY`, a macro
   defined as text that cannot compile

Three of the eight are invisible from `hsc`'s own flag list. The rule that came
out of it: when something is missing, read `ghc.lprl` before concluding anything
about GHC being broken. It held for 6.2.2 too: `hsc2hs`'s flags, the 32 `-u`
symbols on the link line, `-fwrapv` and `-std=gnu89` all came from reading
the Makefiles and `DriverPipeline`, not from the compiler's own help text.
