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
