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

## Correction: the crash is a .hi wire-format mismatch, not the RTS (2026-09-16)

- **The 00:55 root cause above is wrong.** Traced with gdb (breakpoints on
  newByteArrayzh_fast, allocate, allocGroup, getMBlocks; R1 read from
  MainCapability+16). readBinMem loads Prelude.hi correctly (allocate 0x26b2
  words = the 79232-byte file, then the two 8-byte FastMutInt refs). The
  next newByteArray# is the first `getFS` of `getDictionary`, and its R1 is
  0x0100000050010000: the first eight bytes at the dictionary offset 0x6688
  (after the 8-byte count 0x46f = 1135 entries) read as the Int64 length the
  pristine `getFS` expects. allocate then gets 0x2000000a002002 words,
  allocGroup 0x100000050011 blocks, getMBlocks 0x1000000501 megablocks, mmap
  fails ENOMEM, and my_mmap prints the lnat size with `%d`: 1343225856 is
  the low 32 bits. The RTS allocated exactly what the misparsed length asked
  for; the 6.4 megablock/storage backport is not needed for this.
- **Why the bytes are what they are.** Those bytes are
  `01 00 00 00 50 01 00 00 00 72 01 ... 00`: the `Binary [a]` list encoding
  (tag 0x01, 4-byte Word32 char, ..., terminator 0x00) of "Prelude", then
  "base", "GHCziS...". Stage-1 (build/rebase622/try622/utils/Binary.hs) has
  phase4/patches/0004: `putFS bh s = put_ bh (unpackFS s)` and a matching
  `getFS` via `mkFastString`, because the mhs FastString shim has no
  ByteArray#. Every .hi stage-2 can see -- the libraries (built by
  build/ghc622-mhs/ghc on 2026-09-10) and the 220 stage2/ modules -- is in
  that format; stage-2's Binary is the pristine one (src/, D11) and reads
  length + raw bytes. Patch 0004 changes two wire formats: FastString (above)
  and Integer (pristine: tag byte + S#/J# limbs; 0004: Int8 sign + [Word8]
  base-256 limbs). Ratio is unchanged (two fields either way).
- **The 2^56 in the strace size** is a red herring: getMBlocks(nat n) is
  compiled as `shl $0x14,%rbx` on the full 64-bit %rdi, and the upper bits
  leaking through allocate/allocGroup (all `nat` parameters fed W_ values)
  reach the shift. With clean 32-bit truncation the request would still have
  been 1281 megablocks of garbage.
- **Patch 0004's premise was wrong, not its content.** Its header says
  "Interface files written this way are read back by the same code, so the
  format only has to be self-consistent"; a pristine-source stage-2 also
  reads them. Fix options: (a) make 0004 format-preserving (putFS = Int
  length + Latin-1 bytes; Integer = tag 0 + Int64 when it fits, else tag 1 +
  GMP-style limb count/size/limbs) and rebuild stage-1, the libraries and
  the 220 modules; (b) compile stage-2's Binary.hs with the two 0004 wire
  hunks and relink (one module) -- cheapest, but stage-2 then writes the 0004
  format too and a later pristine stage hits the same wall; (c) a stage-2
  Binary that reads the 0004 format but writes the pristine one, used to
  rebuild the libraries, converting the format at this stage. Decision for AB.
  compare-base.sh / scan-hi-stage2.sh read stage-1-written .hi and need
  whichever reader is chosen.
- test/FSize.hs is no longer relevant to this bug (hFileSize was never
  wrong); a Binary round-trip of a FastString and an Integer between a
  stage-1-built writer and a stage-2 reader is the right regression check.

## Patch 0004 made format-preserving (2026-09-16)

- Chosen fix: option (a) of the entry above. The tree the series is
  generated from, build/ghc-6.2.2-run1/ghc/compiler/utils/Binary.hs, now
  writes the pristine wire format and phase4/patches/0004 was regenerated
  from it with phase4/make-patch.sh (series applies exactly, reproduces the
  tree; 259 hunks, 26 patches). FastString: `putFS` writes the Int length
  then the Latin-1 bytes, erroring on a char > 255 as the original's
  UnicodeStr case does; `getFS` reads length + bytes into mkFastString.
  Integer: tag 0 + Int when the value fits a machine Int, else tag 1 + GMP
  signed limb count + size in bytes + little-endian SIZEOF_HSWORD-byte limbs,
  computed by arithmetic; `get` accepts both forms (a pristine writer may
  emit a small value as J#). Ratio was already the same two fields. The
  series.conf header for 0004 now states why the format must match.
- Also folded in: the main/GetImports.hs `__MHS__` readBinaryFile edit that
  DECISIONS.md (the 220-module loop entry) recorded as "tree edit, not yet
  in the patch series"; make-patch.sh refuses an unclaimed hunk, so it is now
  two RUNTIME manifest lines and a sentence in patch 0026's header.
- Checks: `mhs -C -c` of Binary against a scratch copy of the .mhscache
  (MicroHs/bin on PATH for cpphs) compiles, 24 s; a runghc harness
  (scratch FormatCheck.hs) shows the patch's Integer bytes equal an
  independent Data.Bits encoding of S#/J# for 19 values across the Int
  boundary, 2^64 and 2^128, round-trip, and that a J#-form small value is
  read back; "Prelude" encodes as 00..07 + 7 bytes.
- **Not done, and needed before stage 2 can run:** relink stage-1
  (build/ghc622-mhs/build.sh, ~1 h cold; the cache makes Binary + GetImports
  the only recompiles), then rebuild the libraries (build-haskell98.sh) and
  the 220 modules (results.tsv must be cleared: every .hi under stage2/ and
  libraries/ is in the old format), then link-stage2.sh again. The existing
  stage-2 binary reads the new format as is.

## Rebuild with the new format started (2026-09-16, 03:00-03:20)

- **build.sh `all` relinked the old program.** The first relink (pueue-agent
  task 20, `build.sh all`, 9 min) produced a binary that still wrote the list
  encoding: `test/FmtCheck.hs` compiled by it and decoded with
  `test/hidict.py` (a Python reader of the pristine dictionary format) had
  the same bad first length as before, and so did the `GHC/Base.hi` the base
  rebuild (task 22, killed) had just written. Cause: `all` was `hs` + `cc`,
  but `cc` links `ghc-data.c` + `ffi.c` (the comb route, which is what every
  working binary came from: `mhs -o ghc.comb`, comb2c.py, hand ffi table),
  and `hs` writes `ghc.c` -- so `cc` relinked the ghc-data.c of 2026-09-10.
  Linking ghc.c itself fails: it embeds mhs's own `xffi_table`, duplicate
  with ffi.c. build.sh now runs `all` = comb + c + cc; `hs` is a standalone
  step with a note. The mhs -C cache was not the problem: with -v -v it
  prints `invalidate cached Binary` on every run, because validateCache looks
  for `<Module>.hs` only and every .lhs module (Unique, Panic, UniqFM,
  FastMutInt, Module...) fails that lookup and invalidates its importers.
- Chain re-queued as pueue-agent tasks 30-39, each `--after` the previous:
  30 relink (comb route), 31 `test/fmtcheck.sh` (gate: dictionary decodes),
  32 run-base.sh over diag/base-rebuild-order.txt (147 modules, FRESH=1;
  gate: no FAIL row), 33 build-hc.sh, 34 build-libbase.sh, 35
  build-haskell98.sh (now compiles Ix before Array), 36 run-compiler.sh
  FRESH=1 with PREV=results-oldformat.tsv (new: seeds the retry ladder from
  the previous run's flags, so the 25 `-fno-strictness` modules skip the
  4-min doomed -O attempt; gate: 220 OK, no FAIL), 37 build-hc-stage2.sh,
  38 link-stage2.sh, 39 `ghc -B../topdir -C -O Hello.hs` in test/.
  Before that, clean-old-format.sh (task 21) removed the 147 + 30 + 220
  old-format .hi (and .hc/.o) and kept the tsvs as *-oldformat.tsv, because
  6.2.2's recompilation checker reads an existing .hi before recompiling.
  The pre-fix stage-1 binary is kept as build/ghc622-mhs/ghc.pre-0004fix,
  the old stage-2 binary as ghc.oldformat.

## build/Makefile replaces the hand-chained scripts (2026-09-16, 03:20-03:40)

- AB's observation: the hurdle was keeping track of the builds, and pueue is
  a scheduler, not a build system. `build/Makefile` now encodes the whole
  chain as one dependency graph: stage 1 (`build.sh comb` / `c` / `cc` with
  the mhs inputs as prerequisites), the 147 base modules, the 30 haskell98
  modules, the 220 stage-2 modules, their objects, the archives, the link,
  and `test/Hello.hc`. `build/mk/gen-deps.py` writes `build/mk/deps.mk` with
  the real import edges (base-order.py's cpp'd scan for base; build-order.py
  + the HsVersions.h FastString edge for the compiler), so a changed module
  rebuilds exactly its importers. Per-module recipes are
  `build/mk/compile-{base,h98,stage2}.sh`, the loop bodies of run-base.sh,
  build-haskell98.sh and run-compiler.sh: each removes the .hi/.hc first
  (the recompilation checker), keeps the retry ladders, and runs
  `build/mk/check-hi.sh` (hidict.py) on every .hi it produces, so a format
  regression stops the build at the first module. `flags.tsv` seeds the
  stage-2 ladder from the 2026-09-15 run. `make -f build/Makefile status`
  prints what is stale per phase. Run it under pueue-agent; make is the
  record. -j2 is the ceiling for the GHC steps (ulimit -v 8 GB each).
- Checked: `status` after task 30 says stage1 0 steps stale (ghc.comb,
  ghc-data.c and ghc all newer than every input), base/haskell98/stage2 all
  stale. `make .../GHC/Base.hi` compiled GHC.Base in 9 s and hidict.py
  decodes its dictionary: 673 entries, 'GHCziBase', 'base', 'GHCziPrim'...,
  all lengths sane; the file is 72734 bytes against 95965 in the list
  encoding. The relinked stage 1 writes the pristine format.
- pueue-agent task 31 `make-stage2-test`: `make -f build/Makefile -j1 test`,
  log build/make-newformat.log; results also accrue in base-results.tsv,
  results-haskell98.tsv and results.tsv as before. The old drivers
  (run-base.sh, build-hc.sh, build-haskell98.sh, run-compiler.sh,
  build-hc-stage2.sh) still work but are no longer the entry point.

## -j4, and the temp-file collision it exposed (2026-09-16, 03:30-03:50)

- AB: -j1 wastes the machine (16 cores, 30 GB). Restarted as pueue-agent task
  33 with -j4 (memory, not CPU, sets the ceiling: a compile that goes down
  the "heap exhausted" path can reach its 8 GB ulimit -v).
- It failed within minutes: Data.Char "Variable not in scope: isDigit",
  serially too. GHC/Unicode.hi (241 lines of .hc where the 09-10 rebuild had
  1138) decoded as GHC.STRef's interface: dictionary entry 0 'GHCziSTRef',
  --show-iface exports GHC.STRef. Two concurrent compiles had shared a
  preprocessed temp file. SysTools.newTempName names them
  $TMPDIR/ghc<pid>.<ext> and, if the name exists, tries pid+1 -- and the
  shared tmp/ held ghc14.hscpp, ghc15.hscpp... left by the killed runs (each
  pueue task is a fresh PID namespace, so pids repeat), so a compiler
  stepped onto its running neighbour's name. getpid itself is right (two
  compilers printed distinct pids). Serial runs could never hit this.
- Fixes: every compile-*.sh now runs in its own TMPDIR
  ($W/tmp/<Module>.<pid>, removed on exit); check-hi.sh takes the module
  name and hidict.py fails unless dictionary entry 0 is its z-encoding, so
  a swapped interface can no longer pass as OK. Audit of the 31 .hi written
  so far: only GHC/Unicode.hi was wrong; removed and recompiled (1138
  lines). Leftover tmp/ghc* files deleted.

## Stage 2 runs (2026-09-16, 04:39)

- pueue-agent task 34, `make -f build/Makefile -j4 test`: 03:41 -> 04:39,
  **58 min wall** for 125 base modules, 30 haskell98, all 220 compiler
  modules, 399 objects, two archives, the link and the test (the 2026-09-15
  serial loop alone took about 6 h for the 220). Sum of compile times: base
  1992 s, stage 2 7617 s; 23 stage-2 modules at `-O -fno-strictness` (from
  flags.tsv, no doomed -O attempts), 9 `-fno-cse`, Parser `-Onot`; 11 base
  modules took the -fno-strictness retry. No FAIL rows from this run (the
  three FAIL rows in the tsvs are the PrimPacked/Data.Char failures of the
  two aborted runs, each followed by its OK). `make status`: nothing stale.
- **`build/ghc622-stage2/ghc` (37 MB, native, unregisterised) compiles
  `test/Hello.hs`** (`-B../topdir -C -O`): Hello.hc 120 lines, Hello.hi
  decodes (31 dictionary entries). The megablock crash is gone: the
  libraries' .hi files are now in the format the pristine Binary reads.
- compare-base.sh (acceptance test 3): stage 2 compiles GHC/Base.lhs in
  0.6 s (stage 1: 9 s), 7837 lines of .hc against stage 1's 7835. The
  script's normaliser does not catch the differences, which are unique
  numbering (s2Nl vs s2Q6) and the emission order of definitions (dmmax
  before dmcompare on one side, after on the other), both expected between
  two compilers with different unique supplies. Named symbols
  (`GHCziBase_*`) are the same set on both sides; see cmp-base/stage2/.
- Not yet done: scan-hi-stage2.sh (FastString unique collisions) over
  stage2/ and libraries/ with the native compiler; a stage 3 (stage 2
  compiling the compiler: `OUTDIR=stage3` in the scripts, not yet a target
  in build/Makefile); committing today's changes (phase4 patches 0004/0026,
  series.conf, build/Makefile, build/mk/, build.sh, the stage-2 scripts).

## The mblock map under ASLR: RTS patch 0003 (2026-09-16, 09:00-09:45)

- scan-hi-stage2.sh with the native compiler over stage2/ (220), base (147)
  and haskell98 (30): **no duplicated name in any interface** (the D47
  FastString collision is gone from the whole set). But `--show-iface
  parser/ParserCore.hi` segfaulted once in the 397 runs and then passed 160
  repeats; a gdb pass over all 397 saw nothing. Intermittent, ~1 in 400.
- Cause: ghc/rts/MBlock.h's 64-bit HEAP_ALLOCED indexes a 4096-entry map by
  the low 32 bits of the address, and on Linux HEAP_BASE is 0, so the first
  megablock comes from mmap(NULL) and inherits ASLR's random low 32 bits.
  Our ghc is non-PIE: .rodata and .data (static closures, info tables) sit
  at 0x12fa0e0-0x1d00640, map entries 18-29. When the heap's low 32 bits
  land there (26/4096 = 0.6%), the GC takes static closures for heap objects
  and evacuate() dies. Made deterministic with an LD_PRELOAD shim that pins
  the first mmap's hint (build/rts622/alias-test/mmap-alias.c): entries 19
  or 23 -> 6/6 segfaults in evacuate <- GarbageCollect; entries 4 or 2049 ->
  6/6 passes. Full write-up: build/rts622/FINDINGS.md section 9.
- Fix: build/rts622/patches/0003-mblock-map-window.patch -- HEAP_BASE
  0x500000000 on x86-64 (6.4's choice) and the map keyed on (p - HEAP_BASE)
  with 65536 entries, a 64 GB window; getMBlocks barfs on memory outside it.
  Rebuilt libHSrts.a (78/78); `make -f build/Makefile test` relinked the
  stage-2 ghc (libHSrts.a is a prerequisite of the link) and recompiled
  Hello. `make status`: nothing stale.
- Checks with the relinked compiler: strace shows megablocks at 0x500000000,
  0x500100000, ...; the shim's aliasing hints 0/9 failures; ParserCore
  --show-iface 100/100; the three scans 397/397, still no DUP;
  compare-base.sh unchanged (736 symbols both sides). First stage-3-style
  compiles, by hand with the stage-2 -i dirs and outputs in stage3-probe/:
  **PrelNames 3 s** (stage 1: 64 s), 1.32 GB allocated, 4676 collections,
  27 MB residency, 38530 lines of .hc -- stage 1's count exactly;
  **DriverFlags -fno-cse 2 s** (54 s), 21957 lines, also stage 1's count.
- Gotcha for the stage-3 target: 6.2.2's Finder tries every suffix in one
  -i directory before moving to the next, and compile-stage2.sh symlinks the
  .hi-boot files into $ODIR up front, so an empty stage3/ first on -i makes
  `Module.hi-boot-5` resolve Module to stage3/basicTypes/Module.hi, which
  does not exist ("Bad interface file"). Harmless when the importers are
  built in dependency order into the same dir (what the Makefile edges
  guarantee); the by-hand probe put the stage-2 dirs on -i instead.
- Not relinked: the twelve stage-1 test programs in build/ghc622-mhs/test
  (old archive; each ran once and was lucky). Still open: the stage-3
  Makefile target; committing today's changes (this patch, alias-test/,
  FINDINGS.md section 9, DECISIONS.md D50, plus yesterday's list).

## Stage 3, stage 4 and the fixed-point check (2026-09-16, 09:45-10:05)

- build/Makefile gained `stage3` (the 220 modules compiled by the native
  stage 2 from the pristine source into stage3/, objects in obj-stage3/,
  linked as ghc-stage3), `test3` (Hello by stage 3, diffed against stage 2's),
  `stage4` (the 220 compiled by ghc-stage3 into stage4/, .hi/.hc only) and
  `compare3`/`compare4`. gen-deps.py emits the stage-3/4 rules beside the
  stage-2 ones from the same import edges; compile-stage2.sh is reused with
  STAGE3_ENV/STAGE4_ENV (GHC, OUTDIR, OUT, LOGS, USE_FIXUPS=0, FLAGS=/dev/null,
  MODTIMEOUT=1800): no fixups (they stood in for what the MicroHs runtime
  could not read) and no seeded flags (flags.tsv records stage 1's needs).
  link-stage2.sh's OUTDIR=stage3 case now really uses obj-stage3/.
- pueue-agent task 35, `make -j4 test3`: **2 min 6 s wall** for the 220
  modules (sum 204 s, every one at plain -O, no retries; Parser at -Onot the
  slowest at 10 s), 222 objects, the link (ghc-stage3, 37.47 MB) and Hello;
  "stage 2 and stage 3 agree on test/Hello.hc". Stage 1 had needed 7617 s of
  compile for the same 220, and its 25 -fno-strictness modules compile at
  -O natively: their "heap exhausted" was the MicroHs runtime, not the
  compiler looping.
- compare3 (stage3/*.hc, written by the native stage 2, against stage2/*.hc,
  written by the mhs-built stage 1): 5 identical (the 9-line empty modules),
  215 differ. Expected: stage 1 runs on shims whose FastString uniques are
  assigned differently, so local names and emission order differ (Util: the
  same 628 static headers and 69 entry points, reordered), and the 25
  -fno-strictness interfaces stage 1 read give different code downstream
  (TcExpr 17440 vs 17210 lines).
- Task 36, `make -j4 stage4`: 1 min 40 s, 220/220 at -O. **compare4: 218 of
  220 byte-identical**, and both .hi files of the other two identical. The
  two differences are deterministic (each compiler reproduces its own output
  on a rerun, and the two compilers disagree again on a rerun) and understood:
  - utils/Pretty.hc:354 `(L_)22544384000` (stage 2) vs `(L_)1069547520`
    (stage 3): 0x5_3FC00000 vs 0x3FC00000. The low 32 bits are 1.5f (the
    `fullRender mode pprCols 1.5` literal); the upper 32 differ.
    PprAbsC.floatToWord writes the Float into a one-element float array and
    reads it back as a machine Int, so on a 64-bit host the upper half is the
    array's padding: a 6.2.2 64-bit defect, harmless at run time (PK_FLT
    reads the low word) but a reproducibility leak. The stage-1 tree's patch
    0018 (FLOATCAST) casts through Data.Float and has no such half.
  - coreSyn/CoreUtils.hc: one SRT lists Type_funResultTy and Type_applyTy in
    swapped order (with the matching EC_ declarations). SRT order follows the
    Unique order of the free names; external names get uniques in the order
    the compiler first meets them and FastStrings in interning order, both
    through unsafePerformIO counters and so dependent on evaluation order.
    Stage 2 was compiled with 25 modules at -fno-strictness (Type among
    them), stage 3 with none, so their evaluation orders can legitimately
    differ. Pre-8.0 GHC never promised byte-identical stage-2/3 objects for
    this reason.
- Not built: a stage 5 from a linked ghc-stage4, which would show whether
  ghc-stage3 and ghc-stage4 are the same compiler (their inputs differ in
  exactly those two modules). The Makefile stops at stage4's .hc.

## Stage 5: ghc-stage3 against ghc-stage4 (2026-09-16, 10:20-10:35)

- gen-deps.py now emits stages 3-5 from one table (each compiled by the
  previous stage's native compiler; 3 and 4 with objects and a link, 5 as
  .hi/.hc only); the Makefile gained the ghc-stage4 link, `stage5` and
  `compare5` (stage5/ against stage4/, plus the two compiler binaries and
  the two object sets against each other).
- pueue-agent task 37, `make -j4 stage5 && make compare5`: 2 min 14 s wall
  for 222 objects, the ghc-stage4 link (37473016 bytes, the same size as
  ghc-stage3) and 220 modules at -O by ghc-stage4, no retries.
  **compare5: stage 5 vs stage 4 .hc 220 identical, 0 differ.** The stage-2
  -> stage-3 differences did not propagate: a compiler that differs from
  ghc-stage3 only in Pretty.o and CoreUtils.o writes the same 220 files.
- ghc-stage3 vs ghc-stage4: 38 bytes differ, in exactly the places D51
  predicted. obj-stage4 vs obj-stage3: 218 objects identical, utils_Pretty.o
  differs in 1 byte (the upper word of the 1.5f literal) and
  coreSyn_CoreUtils.o in 39 (the swapped SRT pair and its relocations). In
  the linked binaries: 20 bytes in the .note.gnu.build-id (a hash of the
  contents, a consequence), 4 + 4 bytes in .rodata and 9 bytes in .data
  from CoreUtils (the swapped Type_funResultTy/Type_applyTy pointers of
  its SRT and what refers to them) and 1 byte in .data (Pretty's literal):
  20 + 4 + 4 + 9 + 1 = 38.
- So the chain reaches a fixed point at stage 3: ghc-stage3 and ghc-stage4
  are the same compiler up to two bytes-level artefacts whose sources are
  named, and each compiles the compiler to the same output. The Makefile's
  full acceptance run is `make -j4 test3 && make -j4 stage5 && make compare4
  compare5` (about 6 min).
