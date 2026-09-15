# GHC 6.2.2 linked with mhs -- running log

Directory build/ghc622-mhs. Goal: link build/ghc-6.2.2-run1 into a `ghc` binary,
run it on 6.2.2's libraries/base to .hi + .hc, compile a .hc against build/rts622.

## Setup (2026-09-10)

- build.sh: `hs` step = `mhs +RTS -K64M -RTS -C -XCPP <probe defines> <probe -i/-I> Main -o ghc.c`
  with the probe's cache copied to ./.mhscache (the probe cache itself untouched);
  `cc` step = cc -w -O3 main.c eval.c stubs.c ghc.c -lm (mhs.conf [unix] flags,
  as mhs's own mainCompileC would run), plus `-include stubs.h`.
- FFI in the closure (mhs emits `mhs_<f>` wrappers that call f by name, no prototype;
  gcc 16 rejects implicit declarations): rawSystem (SysTools < 603 branch, C body =
  libraries/base/cbits/rawSystem.c Unix branch), setHeapSize + enableTimingStats
  (DriverFlags RTS hooks, no-ops here), getpid (Posix shim), time (Time shim).
  stubs.c provides the first three; stubs.h declares all (unistd.h, time.h).
- topdir/: package.conf (rts + base, "installed" layout so -B<topdir> finds it as
  <topdir>/package.conf; $libdir paths: rts -> build/rts622, includes ->
  rts622 ghc/includes, libraries -> ../libraries), unlit (ghc/utils/unlit/unlit.c
  built with -std=gnu89 -Wno-implicit-int -Wno-implicit-function-declaration
  -include string.h; K&R C), ghc-usage.txt.
- libraries/base: copy of build/rts622/ghc-6.2.2/libraries/base (pristine tarball
  extraction left alone); GHC/PrimopWrappers.hs touched empty as the Makefile does
  when BootingFromHc.
- base-order.py -> base-order.txt: 143 modules, import graph after gcc -E with the
  driver's defines (so __HUGS__/__NHC__ blocks add no edges), SOURCE imports dropped,
  implicit Prelude edge unless -fno-implicit-prelude in the file.
- run-base.sh: per module `ghc -B<topdir> -v1 -C -fglasgow-exts -cpp -Iinclude
  -#include HsBase.h -funbox-strict-fields -package-name base -O <src>`.
- Sandbox note: each Bash call runs in its own PID namespace; `setsid nohup ... &`
  dies with the call (first link attempt died silently) and pgrep cannot see
  earlier calls' processes. run_in_background is the only way to keep a run alive.

## Link

- `mhs -o ghc.c` needs ~13 min in one process and the sandbox kills a foreground
  Bash call at 10 min and a background one under memory pressure (the machine had
  ~8 GB available; two attempts were killed). `-o ghc.comb` is the same compile
  with a quarter of the output text: 8m55s. Main.hs:391 vs 404-410 show the two
  outputs share `outData` exactly, so comb2c.py rebuilds the C array the `.c`
  route would have written, and ffi.c supplies the FFI table by hand. The four
  entries are exactly the closure's foreign imports that the runtime's own
  ffi_table lacks (`rg -o '\^&?\w+' ghc.comb` = 185 names, minus eval.c's 284:
  rawSystem, setHeapSize, enableTimingStats, getpid) and each wrapper is what
  mhs itself emits for that Haskell type (checked in t/ft.c).
- gcc: 7 s, 2.9 MB binary.

### Runtime gap 1: `exitWith` reported as "the impossible happened"

`ghc --version` printed the banner and then panicked with `ExitSuccess`.
DriverUtil.handle has `#if __GLASGOW_HASKELL__ < 501` = `flip catchAllIO`
(catches everything) `#else` a version that re-throws `ExitException`. We
compile with `-D__GLASGOW_HASKELL__=408`, so the driver was catching its own
`exitWith` and Main's `_other ->` arm turned it into a panic. Two edits:
- shims-6.2.2-run1/Exception.hs: `ExitException ExitCode` constructor (4.08's
  hslibs Exception had one), `fromSome` maps MicroHs's `ExitCode` exception
  (System/Exit.hs:19 `exitWith = throwIO`) to it, and `throw (ExitException e)`
  re-throws the bare `ExitCode` so the runtime exits with that code.
- main/DriverUtil.hs: `#if __GLASGOW_HASKELL__ < 501 && !defined(__MHS__)`.

`ghc -B<topdir> --version` -> "The Glorious Glasgow Haskell Compilation System,
version 6.2.2", exit 0. `--numeric-version` -> 6.2.2. `-v` prints the banner,
the package config path and both packages: package.conf parses, i.e. Lexer +
StringBuffer + ParsePkgConf + Packages all run.

## base

### Runtime gap 2: `hFileSize: not available in MicroHs` when reading an interface

`Data.Maybe` (and every other importer) died with "Bad interface file: ./GHC/Base.hi
- user error (hFileSize...)". `Binary.readBinMem` sizes the file with `hFileSize`,
which the IO shim stubs out because MicroHs handles cannot report a size. It has
the *path*, so the mhs branch reads the file whole with `readBinaryFile` (binary
mode = no utf8 layer, System/IO/Open.hs:65) and takes `length` as the size, then
fills the array from the string. Edit: utils/Binary.hs `readBinMem`.

### Runtime gap 3: "arithmetic overflow" at -O -- three separate causes

The panic `the 'impossible' happened ... arithmetic overflow` turned out to be
three different MicroHs-vs-GHC arithmetic differences, found in this order:

1. **Trapping Int overflow.** MicroHs's unix config sets `WANT_OVERFLOW 1`
   (src/runtime/unix/config.h:85), so `+`, `-` and `*` on Int raise
   `Overflow` (eval.c:300-307) where GHC wraps. `CoreUtils.hash_expr`
   multiplies hashes until they wrap on purpose, so CSE died on every module.
   Fixed by building the binary against `rtconf/config.h`, a copy of MicroHs's
   with `WANT_OVERFLOW 0` (build.sh generates it; MicroHs itself untouched).
2. **Checked narrowing into Int8/Int16/Int32.** `fromInteger`/`fromIntegral`
   into those types calls `i8`/`i16`/`i32`, which raise `_overflowError`
   (Data/Int/Int8.hs:32) instead of wrapping modulo 2^n as Haskell 98 and GHC
   do. `Binary Integer` writes the sign of a negative number as an `Int8`
   0xff byte, so *every negative literal in an interface* -- `minInt` in
   GHC.Base, hence GHC.Enum -- crashed the importer as soon as the unfolding
   was demanded (only at -O, only with an -O-built .hi: a 4-line repro is
   t2/Mmin.hs + t2/Nmin.hs). Fixed in utils/Binary.hs (`mhsSigned`, the three
   `Binary IntN` instances) and pre-emptively in basicTypes/Literal.lhs, whose
   `narrow8IntLit`/... folded the narrowing primops through the same checked
   conversions (`narrowSigned`/`narrowUnsigned`, done in Integer).
3. **`negate`/`abs` of `minBound`.** eval.c:6592 checks T_NEG unconditionally
   -- WANT_OVERFLOW=0 does not disable it -- so `abs minBound` raises where GHC
   returns minBound. `CoreUtils.hashExpr` did exactly that. Rewritten to test
   for minBound first (same result, 77).

Method note: the three were separated by bisecting the *input*, not the
compiler: `-O` vs `-O0`, an -O vs -O0 `.hi` for the import, then a 4-line
module carrying one literal. No compiler instrumentation was needed, which
matters because each rebuild is ~9 min (mhs) + 7 s (gcc).

### Runtime gap 4: the demand analyser exhausts the MicroHs stack, then the heap

GHC.Arr and GHC.Real died in `*** Demand analysis:` with the runtime's own
`ERR: stack overflow` (default stack 250000 slots, eval.c:495). `+RTS -K5M`
moved it to `ERR: heap exhausted`; `-K50M -H100M` (1.6 GB) still exhausted the
heap after 465 s. `-O -fno-strictness` compiles GHC.Arr in 19 s. DmdAnal's
fixpoint (`dmdFix.loop`, stranal/DmdAnal.lhs:355-395) accumulates
`plusUFM_C both` thunks across up to 10 iterations; GHC's own strictness
analysis kept those chains short when GHC compiled itself, and mhs preserves
the laziness literally. run-base.sh therefore retries a module once with
`-fno-strictness` when it sees either message, and marks the row.

### Runtime gap 5: `HTYPE_INT` not in scope (Foreign.Storable and 96 modules behind it)

Not a compiler bug: `configure`'s `FPTOOLS_CHECK_HTYPE` probes
(aclocal.m4:726-822) compile a program whose `main() {...}` has no return type,
which gcc >= 14 rejects, so the 6.2.2 configure run in build/rts622 left every
`HTYPE_*` as `#undef` -- the same 2026-toolchain class as D31/D40.
`Foreign/Storable.hs:178`, `Foreign/C/Types.hs` and `System/Posix/Types.hs`
need them. `gen-htypes.c` reruns the probes' logic verbatim (integer type ->
Int/Word plus width, else Float/Double by size) and its output is appended to
`build/ghc-6.2.2-run1/ghc/includes/config.h`; `topdir/includes` now points at
that directory rather than build/rts622's. HTYPE_DEV_T and HTYPE_SIG_ATOMIC_T
had configure's fallback values (Word32/Int32) and are `#undef`'d first: the
probe says Word64/Int32 here.

### RTS acceptance

build-hc.sh compiles every produced .hc with the flags build/rts622/build-rts.sh
uses for the RTS's own .hc files (`-x c -include Stg.h -std=gnu89 -O -DNO_REGS
-DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=622`), plus `-Iinclude -I.` for
base's headers and for the `Control/Concurrent_stub.h` the driver emitted.
101/101 objects. GHC/Base.o has 563 defined symbols and 17 undefined, of which
15 are in build/rts622/libHSrts.a (`stg_ap_*`, `stg_upd_frame_info`, `newCAF`,
`MainCapability`, `gcdIntzh_fast`, ...) and 2 are base's own
(`GHCziErr_error_closure`, `__stginit_GHCziErr_`).

## Result

`base-results.tsv` (run 4, FRESH=0 on top of runs 1-3): **136 OK / 143**, plus
`GHC.PrimopWrappers` after generating it properly (see below) = 137. Seven
rows failed:

- `Data.Complex` (`ERR: heap exhausted`, 405 s, at `-O` and at
  `-O -fno-strictness`), `Data.Graph` and `System.Console.GetOpt` (killed at
  the 900 s timeout with no message). Same shape as gap 4 but not cured by
  `-fno-strictness`, so a second space leak; left open per the stop conditions
  rather than ground at. Note for a future run: run-base.sh only retries on
  the runtime's error strings, so a *timeout* does not trigger the fallback.
- `System.Directory`, `System.Random`, `Text.Regex`: each imports one of
  `System.Time`, `System.CPUTime`, `Text.Regex.Posix`, which are `.hsc`
  sources. There is no `hsc2hs` in the chain (it is `ghc/utils/hsc2hs/Main.hs`,
  Haskell 98, so mhs should manage it) and `base-order.py` only lists
  `.hs`/`.lhs`, so the four `.hsc` modules are not in the order file at all.
- `GHC/PrimopWrappers.hs` was the empty file the Makefile touches when
  `BootingFromHc=YES`; GHC reads an empty file as `module Main` and asks for
  `main`. Generated the real 625-line module with the chain's own
  `build/gen622/genprimopcode --make-haskell-wrappers < prelude/primops.txt`;
  it compiles in 10 s.

`build-hc.sh`: 137 `.hc` -> 137 `.o`, no failures.

### The three open modules, retried

`-O -fno-strictness`, `+RTS -K5M`, 900 s limit: `Data.Complex` `ERR: heap
exhausted` after 405 s, `Data.Graph` and `System.Console.GetOpt` killed at the
limit with no message. So it is not the demand analyser: a second space
blow-up, in a pass that produces no output before it dies. Stopped here rather
than guess-and-relink (three fixes to one symptom is the stop condition);
`-ddump-simpl-stats` or a `-v3` run left to finish would name the pass.

## hsc2hs (separate run, 2026-09-10; details in build/hsc2hs-mhs/FINDINGS.md)

`ghc/utils/hsc2hs/Main.hs` built with mhs (`-D__GLASGOW_HASKELL__=622`, Parser
instances split Functor/Applicative/MonadFail/Alternative, local `System` shim
with `system`). Driver adds `--cflag=-std=gnu89`: gcc 16 rejects HsBase.h's K&R
`__hscore_s_isblk(m)` otherwise. The four .hsc modules generated with
`-Iinclude -I<ghc/includes> -I.` as libraries/base/Makefile does; they and
System.Directory, System.Random, Text.Regex compiled 7/7 at -O (System.Time
89 s, the rest 4-30 s) and 7/7 .hc -> .o. base-results.tsv: 144 OK / 3 FAIL
(GHC.PrimopWrappers row corrected to OK, stale importer FAIL rows removed).

### Runtime gap 8: the three "space blow-ups" were an infinite inlining loop from a FastString unique collision in the shim

Full write-up: `diag/FINDINGS.md`. `Data.Complex`, `Data.Graph` and
`System.Console.GetOpt` all stall in the *second* `*** Simplify:` (phase 2,
the first with real inlining) and `-ddump-inlinings` shows an endless cycle:
the simplifier considers `GHCziList.zdwzdsmaximum` (the *worker*) and finds
on it the *wrapper's* unfolding `\w -> case $w$smaximum w of ww -> I# ww`, so
every inlining recreates the call. `--show-iface GHC/List.hi` has two
signatures named `$w$smaximum` and no `$smaximum`: the interface was written
with two FastStrings sharing one unique (Binary's dictionary is a UniqFM
keyed by that unique). Cause: the shim's `intern` read its table snapshot,
then let `M.lookup` force the string, and `mkWorkerOcc`'s `"$w" ++
occNameString occ` forces the parent's FastString, whose strict unique field
runs a nested `intern`; the outer write then clobbers the inner one. Needs an
existing key sharing the prefix (`$wlgo`), which is why only five interfaces
were hit (GHC.List, GHC.Float, GHC.Real, Data.Array.Diff, Text.Html;
`diag/scan-hi.sh`). Fix: force the string before reading the table (both
shim copies, `diag/faststring-intern.patch`); 5-line mhs reproducer
`diag/repro/Intern.hs`. Relink 9 min. Downstream damage was real
(`Foreign.C.Types` had the worker in its `atan2` dictionary slot; GHC.Real's
Ratio dfuns were renamed for every importer), so base was rebuilt beside the
old tree: `libraries/base-rebuild`, `diag/run-base-rebuild.sh`, **147/147
OK** in 31 min, `diag/hcobj-rebuild` 147/147 `.o`, zero collisions. The old
tree, `hcobj/` and `base-results.tsv` are untouched for the link agent;
Data.Complex 47 s (`-fno-strictness`), Data.Graph 25 s, GetOpt 6 s.
