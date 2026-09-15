# Stage 2: the mhs-built GHC 6.2.2 compiles GHC 6.2.2's compiler proper -- running log

Directory build/ghc622-stage2. Stage 1 = build/ghc622-mhs/ghc (compiler proper
on the MicroHs runtime). Goal: a NATIVE ghc (6.2.2 compiled by 6.2.2, via .hc
and gcc, linked against build/rts622 and the stage-1-built base).

## Setup (2026-09-10, 11:00-11:10)

- src/: pristine `ghc-6.2.2-src.tar.bz2` extraction of ghc/{compiler,includes,
  utils,driver,rts}, mk/, libraries/{base,haskell98,unix}. Added (nothing else
  touched): compiler/parser/Parser.hs, ParserCore.hs, main/ParsePkgConf.hs
  (build/gen622, our happy), compiler/prelude/primops.txt and the ten
  compiler/primop-*.hs-incl (gen622; in the compiler root, where the Makefile
  generates them and where `-I.` finds them from the unlit'd temp file),
  compiler/main/Config.hs (written here: 6.2.2 values, unregisterised, no NCG,
  "installed" tool layout, cBooterVersion "6.2.2"), includes/config.h and
  includes/DerivedConstants.h (copies of build/ghc-6.2.2-run1/ghc/includes,
  i.e. configure's x86_64 output + the HTYPE block).
- Imports outside the tree under `__GLASGOW_HASKELL__=602` (gcc -E over all
  modules, script in the session): only base and haskell98 modules (Array,
  Char, Directory, IO, List, Maybe, Monad, Ratio, System, Time, CForeign).
  System.Posix.Internals/Signals are in base. No `unix`, no `posix`.
- libraries/haskell98: copy of the tarball's, compiled with stage 1
  (build-haskell98.sh: -C -O -package-name haskell98 -package base): 30/30 in
  ~1 min (Array needs Ix first; the script runs alphabetically, Array redone
  by hand), 30/30 .hc -> .o (-fwrapv), libHShaskell98.a.
- topdir/: package.conf with rts, base, haskell98 ("installed" layout, $libdir
  = topdir); base's library_dirs -> build/ghc622-mhs/lib (via libraries/
  base-lib), rts's extra_ld_opts = the 32 -u symbols of rts/package.conf.in
  and extra_cc_opts = -std=gnu89 -fwrapv so the driver's own via-C pipeline
  gets the two 2026-toolchain flags (build-hc.sh / FINDINGS-link.md); unlit
  and ghc-usage.txt copied from build/ghc622-mhs/topdir; includes ->
  src/.../ghc/includes; rts -> build/rts622; libraries/base -> the stage-1
  built base (read only).
- order.txt (make-order.py, 220 modules): phase2/build-order.py over the
  pristine tree minus ghci/ilxGen/javaGen/nativeGen and HsGeneric, DsMeta,
  TcSplice, Convert (Makefile EXCLUDED_SRCS without GHCI), plus one edge the
  textual scan misses: HsVersions.h `import qualified FastString` unless
  COMPILING_FAST_STRING (found the hard way: Constants failed with "Could not
  find interface file for FastString" at HsVersions.h:82). Order starts
  PrimPacked, FastString, Constants, Config; Parser at row 156, Main at 219.
  vs the probe's build/order-6.2.2.txt: minus the 16 GHCi/ILX/Java modules,
  plus Config.
- run-compiler.sh: explicit -o stage2/<dir>/M.hc -ohi stage2/<dir>/M.hi with
  -istage2/<dir> for the 23 ALL_DIRS and the 80 .hi-boot* files linked into
  stage2/ (Makefile `boot`); flags per Makefile (header of the script);
  ladder -O -> -O -fno-strictness -> -O0 on runtime death/panic/timeout only;
  ulimit -v 8000000, 3600 s per attempt, +RTS -K50M for the MicroHs stack.
  Smoke test: Config 2 s, PrimPacked 10 s at -O, outputs where expected.
- 11:10 full run started in the background (FRESH=0 on top of the two rows).
- 11:20 first 16 modules through at plain -O (FastString 23 s, CmdLineOpts
  25 s, the rest 2-12 s). build-hc-stage2.sh (build-hc.sh's recipe +
  -I<compiler>/parser for hschooks.h) compiles them 16/16, and the compiler's
  two C files (parser/hschooks.c, cbits/rawSystem.c) compile with gcc 16 with
  no patch; hschooks.o defines defaultsHook/setHeapSize/enableTimingStats/
  ghc_strlen/ghc_memcmp*.  link-stage2.sh and link-prog.sh (link.sh with the
  compiler as a parameter, + -lHShaskell98) written, untested until there is
  a binary.

## Fixes during the run (11:25-11:50)

1. **`Ctype`: `ERR: getb_utf8`** (MicroHs runtime, UTF-8 decode). parser/
   Ctype.lhs is the only non-UTF-8 file in the tree (Latin-1 bytes 0xa1-0xff,
   all in `-- \xNN` comments, lines 218-312). Not the StringBuffer shim (it
   reads bytes with `B.readFile`), not the OPTIONS scan (stops at the first
   non-pragma line): `-v3` dies right after cpp, i.e. in
   `main/GetImports.hs:23-24` `openFile`+`hGetContents` -- a text-mode handle,
   byte-transparent under GHC, UTF-8-decoding under MicroHs. Two actions:
   (a) stage-1 tree fix, `build/ghc-6.2.2-run1/ghc/compiler/main/GetImports.hs`:
   `#if defined(__MHS__)` branch using `readBinaryFile` (as `readBinMem` in
   utils/Binary.hs already does), comment `-- mhs`; **relink deferred** until
   the loop is done (one compiler process at a time); `build/6.2.2-run1.patch`
   must be regenerated then, and `sh phase4/make-patch.sh` rerun.
   (b) to unblock now: `fixups/parser/Ctype.lhs`, the pristine file with each
   byte >127 spelled `\xNN` (comments only; `diff` shows 95 comment lines and
   nothing else), compiled by hand with the loop's flags (compile-one.sh) into
   stage2/parser (rc=0, 27861-byte .hc). run-compiler.sh now compiles
   `fixups/<path>` when it exists (row marked `[fixups]`; USE_FIXUPS=0 turns
   it off, for a native compiler). The pristine tree is untouched.
2. **`ParsePkgConf`: "unknown flags in {-# OPTIONS #-} pragma: _GHC"**. Our
   happy (1.19.5 template) writes `{-# OPTIONS_GHC -w #-}`; 6.2.2's
   `matchOptions` matches the prefix `OPTIONS` and takes `_GHC` as a flag.
   Rewrote line 1 of the three generated parsers to `{-# OPTIONS -w #-}`
   (generated files, ours).
3. **The generated parsers import `Control.Applicative(Applicative(..))` and
   `Control.Monad (ap)`** -- post-AMP boilerplate of the 1.19.5 template; no
   6.2.2 base has Control.Applicative, and the mhs probe never noticed
   because mhs has it. The three parsers use `%monad { P }`, so no
   `HappyIdentity` instances are emitted and nothing uses `ap`: the two import
   lines were deleted from each (verified: `rg -w ap` finds nothing).
   Cascade so far: Lexer (needs Ctype), DriverState (needs ParsePkgConf);
   Parser/HscMain/... will fail in this pass and be picked up by the FRESH=0
   resume pass together with Lexer and ParsePkgConf.

## State at interruption (last write 11:50; recorded 2026-09-15)

The run died with the session (see DECISIONS.md D49). `results.tsv` has 84
rows of 220: **80 OK, 4 FAIL** (Ctype, Lexer, ParsePkgConf, DriverState, all
fixed above and waiting for the resume). 77 of the 80 compiled at plain `-O`,
three needed `-O -fno-strictness`. Last row written: `InstEnv`; next in
`order.txt`: `NameEnv`. `obj/` has 18 `.o` (the first 16 modules plus the
two C files, all from the 11:20 batch). Nothing linked.

Outstanding before or at the resume:

- The stage-1 fix (a) to `GetImports.hs` is in `build/ghc-6.2.2-run1` but
  the stage-1 binary `build/ghc622-mhs/ghc` (10:04) was not relinked, and
  `phase4/make-patch.sh` has not been rerun (it will stop on the new hunk
  until `series.conf` classifies it; `phase4/FINDINGS.md` section 8).
- Resume: `FRESH=0` on the same order with `run-compiler.sh`; `Ctype`
  compiles from `fixups/` until the stage-1 binary carries fix (a).
- Then `build-hc-stage2.sh` over the rest, `link-stage2.sh` (untested),
  `compare-base.sh` and `scan-hi-stage2.sh` for the stage-1/stage-2 check.

## Resume (2026-09-15, 20:42)

- The repository moved from `~/work/haskell/ghc-bootstrap` to
  `~/code/haskell/ghc-bootstrap` between the two sessions. Every script had
  the old root as a literal `R=...`; all of them (here, `build/ghc622-mhs`,
  the other `build/` probes, phase0-3) now read `GHC_BOOTSTRAP_ROOT`, set by
  `mise.toml` at the repo root, and stop with `GHC_BOOTSTRAP_ROOT: not set`
  otherwise. The seven absolute symlinks the pipeline uses (`topdir/includes`,
  `topdir/rts`, `libraries/base`, `libraries/base-lib`, the stage-1
  `topdir/{rts,includes}`, `hsc2hs-mhs/ghc/includes`) were re-pointed; the
  `.hi-boot` links under `stage2/` are recreated by run-compiler.sh. The
  stage-1 binary carries the old path only in 631 source-location strings of
  its error messages, so it runs unchanged. The `.tsv` records keep the old
  path as history.
- The loop runs as `pueue-agent` task 7 (label `stage2-resume`, default
  group, one task at a time), command
  `FRESH=0 sh build/ghc622-stage2/run-compiler.sh > run-stage2.log 2>&1`,
  so it survives the session. Future runs: `mise exec -- sh ...`, or set
  `GHC_BOOTSTRAP_ROOT` in the command string.
- 20:42 `Ctype` taken as cached (the hand-compiled fixups output). 20:48
  `Lexer` OK at `-O -fno-strictness` after `-O` died, 318 s, 36078-line .hc.
  Relink of stage 1 with the `GetImports` fix and the `series.conf` hunk
  still deferred until the loop is done.
- 21:10-21:40 **The `-O` deaths are unbounded memory growth, not a small
  heap.** Every first attempt that failed so far (Lexer, OccurAnal, BinIface,
  CgStackery, CgBindery) ended with the MicroHs runtime's `ERR: heap
  exhausted` (default heap 50M cells, `HEAP_CELLS` in eval.c; tunable with
  `+RTS -H<cells>`). Test (`tmp/htest/run.sh`, CgStackery at plain `-O`,
  run beside the loop as pueue-agent tasks 9/10): with `-H200M` under the
  loop's 8 GB `ulimit -v` the process reached 7.7 GB RSS and died with
  SIGSEGV at 63 s; with a 16 GB limit it reached 15.9 GB RSS and died with
  SIGSEGV at 154 s. Resident memory grows well past the cell heap, so more
  heap only buys time. Two consequences: (a) the `-O -fno-strictness` rung
  is the right outcome for these modules, not a tuning failure, and the
  compiled code differs only in optimisation; (b) the runtime segfaults
  rather than reporting the failed allocation when `ulimit -v` bites, which
  the ladder happens to treat as retryable (rc 139). Whether the growth is
  the strictness analyser proper or a D47-style semantic difference feeding
  it is not established.
- 22:33 **`ParserCore` FAIL, rc=1, a type error in the generated parser** --
  the first real failure of the resume, and the third generator fault (after
  fixes 2 and 3 above). `parser/ParserCore.hs:347: Couldn't match "String ->
  Int -> ParseResult a" against "P HappyAbsSyn"`, in `action_0 (42) =
  happyShift action_2`, for every action_*. ParserCore's monad is a synonym
  for a function type (`ParserCoreUtils`: `type P a = String -> Int ->
  ParseResult a`); Parser and ParsePkgConf use Lexer's newtype `P` and were
  fine. The happy 1.19.5 template writes the monad parenthesised in the
  action_*/happyReduce_* signature block, `(P) HappyAbsSyn`, and 6.2.2's
  `tcHsType` applies the parenthesised head without saturating the synonym:
  the result is a bare `TyConApp P [HappyAbsSyn]`, which `uTys`
  (TcUnify.lhs:620-672) strips no `NoteTy` from and cannot unify with a
  `FunTy`. Later GHCs expand synonyms in the unifier, which is why happy
  never saw it. Experiments (tmp/pctest, pueue-agent tasks 11-14, `-O0`
  against the stage2 interfaces): as generated FAIL; `() =>` removed FAIL;
  signature block removed OK (748 KB .hc); **parentheses removed OK** (494
  KB .hc). ParserCore is on Main's path (HscMain imports it).
  Fix, permanent and in the generator, not a fixups/ workaround: new
  `phase4/fix-generated-parsers.sh` applies all three rewrites (OPTIONS_GHC,
  the two imports, the parentheses) and is called by
  `phase4/regen-generated.sh` and `build/gen622/regen.sh` after each happy
  run; applied to the three parsers in this tree and in
  `build/ghc-6.2.2-run1` (the reproduce script's reference), which are now
  identical again -- the run1 copies had never received fixes 2 and 3
  either. `build/repro-622` is a reproduce output and will pick it up on the
  next run. ParserCore then compiled by hand into stage2/parser
  (compile-one.sh, -O, pueue-agent task 15) so HscMain (row 215) finds it;
  the FAIL row stays in results.tsv as history, an OK row appended after.
- 23:30 **`TcForeign` FAIL, rc=1: `nativeGen/NCG.h:52: fatal error:
  ../includes/NativeDefs.h: No such file`** (gcc -E, via the driver's cpp
  phase). TcForeign.lhs:180 includes NCG.h for the `*_TARGET_ARCH` macros
  (the Alpha argument-size check); NCG.h unconditionally includes
  `../includes/NativeDefs.h`, which `ghc/includes/Makefile` generates
  (`all :: NativeDefs.h`, from `mkNativeHdr.c`, whatever the NCG setting)
  and which no tree of ours had: the mhs probe used cpphs, which on a missing
  `#include` writes `#line 1 "missing file: ..."` and exits 0 (verified on a
  two-line file), so 226/235 never noticed. TcForeign is on Main's path
  (TcRnDriver imports it). Generated it as the Makefile does, with the
  mkDerivedConstants recipe of phase4/reproduce-6.2.2.sh (gcc -include
  stdio.h -DNO_REGS -DUSE_MINIINTERPRETER, unresolved symbols ignored): 43
  lines of OFFSET_*/TSO_*/BDESCR_* defines, installed in this tree's
  ghc/includes and in build/ghc-6.2.2-run1/ghc/includes; step 5b added to
  reproduce-6.2.2.sh. TcForeign then compiled by hand into stage2/typecheck
  (compile-one.sh, -O, pueue-agent task 16) ahead of TcRnDriver, seven
  rows on. With this and ParserCore, the loop's two FAILs today were both
  inputs the probe could not have checked, not compiler behaviour.

## Loop complete (2026-09-16, 00:31)

- pueue-agent task 7 ended `Success`: `stage2: 218 OK, 2 FAIL` from the
  loop's own count, plus the two hand rows for ParserCore and TcForeign:
  **220 of 220 modules have `.hc` and `.hi` under stage2/**. 25 modules
  needed `-O -fno-strictness` (all `ERR: heap exhausted` at `-O`, see the
  21:10 entry), none needed `-O0`; Parser at `-Onot` as the Makefile says.
  results.tsv has 226 rows: the 6 FAIL rows (September's four, ParserCore,
  TcForeign) are history, each followed by its OK.
- Wall time for today's 140 modules: 20:42 to 00:31 (3 h 49 min), of which
  the 25 doomed `-O` attempts cost about 4 min each, roughly 1 h 40 min.
- Next: build-hc-stage2.sh (FRESH=0, pueue-agent task 17) for the 202
  remaining `.o`, then link-stage2.sh (untested), then compare-base.sh /
  scan-hi-stage2.sh against stage 1.

## Native compiler links; does not yet run (2026-09-16, 00:55)

- **Link OK.** build-hc-stage2.sh (task 17): 220/220 `.hc` -> `.o`, plus the
  two C files, 222 objects. link-stage2.sh (untested until now) linked on the
  first try: a 37 MB `build/ghc622-stage2/ghc`. `./ghc -Btopdir --version`
  prints "The Glorious Glasgow Haskell Compilation System, version 6.2.2" and
  `--numeric-version` prints 6.2.2. This is a native GHC 6.2.2 binary built by
  the mhs-built GHC 6.2.2.
- **It cannot compile yet.** `./ghc -Btopdir -C -O Hello.hs` (Main = putStrLn
  "hello") dies `ghc: out of memory (requested 1343225856 bytes)` in the
  Renamer/typechecker phase, after Parser, i.e. while loading Prelude's
  interface. Deterministic (same number every run), and the same with
  `ulimit -v unlimited`, so not the vmem cap.
- **Not hFileSize.** `readBinMem` (Binary.hs:255) sizes its buffer from
  `hFileSize`; a direct test (build/ghc622-mhs/test/FSize.hs, built by the
  stage-1 ghc, run on rts622: fsize-probe task 19) returns the correct size,
  and strace shows the kernel reporting Prelude.hi's st_size = 79232 correctly
  three times just before the crash.
- **Root cause: the megablock allocator's 64-bit arithmetic (RTS).** strace:
  right after fstat(Prelude.hi)=79232, the RTS issues
  `mmap(0x7fee50100000, 72057595381153792, ...) = ENOMEM`. That size is
  2^56 + 1343225856; the printed "1343225856" is 0x50100000, the low 32 bits
  of a megablock address (blocks were just placed at 0x7fee503/502/501/500..
  00000). getMBlocks(n) computes `size = MBLOCK_SIZE * n` (MBlock.c:196), so
  n = size/2^20 ~= 2^36 + 1281 ~= 68e9 megablocks: the block allocator handed
  getMBlocks a garbage count on ~the 5th megablock request, and it tried to
  mmap 64 PB. Only ~5 MB of megablocks had been allocated, so this is NOT the
  4 GB HEAP_ALLOCED false-positive the MBlock.h hack warns about; it is the
  garbage-n bug. This reproduces, on unregisterised x86-64, the 2004 symptom
  build/research-6.2-x86_64.md records ("`getMBlock: mmap: Invalid argument`
  with garbage sizes at the third mblock request; root cause not recorded")
  and matches its note that the real 64-bit mblock map / storage rework landed
  in 6.4 (61ccfec, 2004-11-10). FINDINGS-link.md had flagged this area ("still
  dies after 4 GB of address space; the 6.4 backport is not needed yet") --
  it is needed now, though the trigger is garbage n, not the 4 GB wrap.
- **Open.** Which computation in BlockAlloc.c/Storage.c overflows to produce
  the garbage megablock count is not yet pinned down. The fix is very likely
  the 6.4 RTS megablock/storage backport; that is a new phase (edit rts622,
  rebuild libHSrts.a, relink both stage-1's programs and stage-2), a scope
  decision for AB. Everything up to and including a linked native ghc stands.
- Scratch (all under gitignored tmp/ or build/ghc622-mhs/test): tmp/pctest
  (ParserCore variants), tmp/htest (heap tests), test/FSize.hs (hFileSize
  probe, kept -- it is a clean regression check for the storage fix).
