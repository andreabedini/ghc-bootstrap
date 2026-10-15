# GHC 6.6 built by the chain's GHC 6.2.2 — working notes

Started 2026-09-25. Question (blog posts 1, 8, 9; Tournier's comment under
Breitner 802: Guix's 6.6 rung "needs 5.04 at least"): can the 6.2.2 that the
chain produces build GHC 6.6?

Layout:
- `src/ghc-6.6/`     pristine `ghc-6.6-src.tar.bz2` (sha256 79b2a291…) plus the
                     edits listed below
- `ghc622-inst/`     the chain's 6.2.2 presented as an installed compiler:
                     `bin/ghc` (-B build/ghc622-stage2/topdir + side package.conf),
                     `bin/ghc-pkg` (6.2.2's own ghc-pkg, compiled by ghc-stage3 from
                     build/ghc-6.2.2-run1/ghc/utils/ghc-pkg), `package.conf` (stub
                     `unix`: 6.6 stage 1 passes -package unix, and the one module it
                     imports from it, System.Posix.Signals, is in 6.2.2's base)
- `build-66.sh`      configure + make, queued under pueue-agent; logs in `logs/`

Edits to the 6.6 tree (not patches yet; listed so they can become one):
1. `configure`: FPTOOLS_CHECK_PERL_VERSION accepts only perl "v5.6", "v5.8" or
   "version 6"; this machine has 5.42. `grep "v5.6"` -> `grep "v5\."`.
   Original kept as `configure.orig`.
2. `mk/build.mk` added (not in the tarball): see the file.

Host tools deliberately kept out of PATH: ~/.ghcup/bin (configure's ghc-pkg
fallback found the machine's GHC 9.x there on the first run). happy is the
chain's happy-mhs 1.19.5 (configure needs >= 1.15 only if the shipped
Parser.hs were missing; 6.6's tarball ships Parser.hs, Lexer.hs, ParserCore.hs).
No alex: the shipped Lexer.hs is used.

## Run 1 (pueue task 47, 2026-09-25 11:10, 87 s): failed in utils
configure passed (ghc 6.2.2 found, our ghc-pkg matched, happy 1.19.5, no
alex, "ld understands -x" probe fails on implicit int, harmless). `make`
died in `utils/genprimopcode`: `-package parsec`, unknown to our 6.2.2; then
`compiler` boot could not run genprimopcode (exit 127). Other utils name
`-package lang -package util -package text` (ghc-pkg, genapply, hsc2hs).

Fix: 6.2.2's own `libraries/parsec` (10 modules, pure Haskell) compiled by
ghc-stage3 with `--make -O -fglasgow-exts -package-name parsec` into
`ghc622-inst/libraries/parsec` + `libHSparsec.a`, registered in the side
package.conf; `lang`, `util`, `text`, `data` registered as empty packages
(in 6.2.2 they were hslibs packages; 6.6's utils name them only for pre-6.0
bootstrap compilers and import nothing outside base). Checked: a parsec
program compiles, links and runs with all of them on the command line.

## Run 2 (pueue task 48, 11:14-11:3x): stage 1 built; libraries failed on hsc2hs
`compiler/stage1/ghc-6.6` linked at 11:21 (41 MB, 241 modules, ~9 min of
compiling by our 6.2.2); it then compiled 6.6's rts from .cmm via C. The
libraries failed from one cause: `hsc2hs-inplace` on System/CPUTime.hsc,
gcc 16 rejecting HsBase.h's K&R definitions (`type of 'm' defaults to 'int'`),
so base's `depend` failed, base compiled alphabetically, and everything after
cascaded from "Failed to load interface for `Prelude'". Fix: build.mk
`SRC_HSC2HS_OPTS += --cflag=-std=gnu89 --cflag=-fpermissive --cflag=-w`.
The "cannot find libHSxxx.a on library path (ignoring)" lines are 6.6's own
ghc-pkg-inplace registering in-place packages before their libraries exist.

## Run 3 (pueue task 49, 11:3x): all libraries built; killed at the rts link problem
With the hsc2hs flags, stage 1 built every 6.6 library (base 32 MB, Cabal,
haskell98, parsec, readline, regex-base/posix/compat, stm, template-haskell,
unix) and started stage 2. Only error in the log: `cabal-setup`, a program
compiled without the -optc flags (HsBase.h K&R again). A hello-world through
`compiler/stage1/ghc-inplace` compiles with `-optc-std=gnu89 -optc-fpermissive
-optc-fwrapv` but fails to link: `deRefStablePtr` defined in both
`libHSrts.a(Stable.o)` and `libHSrts.a(AutoApply.o)`. The rts is compiled
through ghc-inplace (UseGhcForCc), so build.mk's SRC_CC_OPTS never reached it
and gcc's default C mode turned Stable.h's `extern inline` functions into
external definitions (the [D41](../../DECISIONS.md#d41--it-links-and-compiled-haskell-runs) issue in reverse). Fix: the -optc flags in
SRC_HC_OPTS for every compile; `make -C rts clean`; rerun. Run 3 was killed
during the stage-2 compile to avoid the same link failure there.

## Run 4 (pueue task 50): rts rebuilt, stage 2 compiled, failed at the stage-2 link
`cannot find -lHSrts_thr`: compiler/Makefile.ghcbin adds `-threaded` to the
ghc binary link unconditionally, and build.mk's `GhcRTSWays=` builds no
threaded RTS. Edit 3 to the tree: `-threaded` moved inside the
`GhcWithInterpreter == YES` block, whose comment in compiler/Makefile is the
stated reason for it. Original kept as `Makefile.ghcbin.orig`.

Gotcha found on the way: `GhcWithNativeCodeGen` is derived from
`GhcUnregisterised` inside config.mk, before build.mk is read, so it stayed
YES; stage 1 and 2 therefore include the (unused) nativeGen modules. Code
generation still went via C because the compiler's own Config says
unregisterised (every compile line shows -fvia-C). A clean rerun should set
`GhcWithNativeCodeGen=NO` explicitly in build.mk; not changed mid-build
because the stage-2 objects were compiled with nativeGen on the module list.

## Run 5 (pueue task 51, 11:37, 31 s): make rc=0. GHC 6.6 built by our 6.2.2.
`compiler/stage2/ghc-6.6` (44 MB) linked; `make` exits 0. Programs compiled
by stage 1 and by stage 2 run correctly: sorting, Data.Map, 2^200 through
GMP, Int bounds, Double show/read/round, a caught divide-by-zero, and the
length of 1000! (test/T2.hs, 2568 digits). Edit 4: `cc-options: "-std=gnu89",
"-fwrapv"` in rts/package.conf.in, re-registered with `make -C rts boot`
(ghc-pkg-inplace field rts cc-options confirms), so the in-place 6.6 needs no
flags on the command line. `GhcWithNativeCodeGen=NO` added to build.mk for
clean runs. All four edits are `ghc-6.6-by-622.patch` (69 lines), which
applies to the pristine tarball; `FRESH=1 TREE=<dir>` in build-66.sh
re-extracts and applies it.

What this build uses that a bootstrappable.org-style rung should not: the
tarball's pre-generated compiler/parser/Parser.hs, Lexer.hs and
ParserCore.hs (happy 1.19.5 is available for the .y files; there is no alex).
Also unmeasured: registerised code (this is unregisterised via C throughout),
GHCi, profiling, and whether this 6.6 builds 6.8/6.10.

## Verification (pueue task 52, 11:44-12:02): pristine tarball + patch, clean tree
`FRESH=1 TREE=build/ghc66-by-622/src-verify`: re-extracted ghc-6.6-src.tar.bz2,
applied ghc-6.6-by-622.patch (4 files), configure 54 s, `make` 17 min 18 s,
rc=0, no Error lines. stage1/ghc-6.6 40.0 MB, stage2/ghc-6.6 42.6 MB (smaller
than run 5's: GhcWithNativeCodeGen=NO drops nativeGen). test/T2.hs compiled
by the verified stage 2 with no extra flags runs correctly (logs-src-verify/
t2-verify.log). The script's own hello step printed "no .../ghc-inplace"
because TREE was given relative and the script had cd'd; fixed (TREE is made
absolute).

Result, stated precisely: the GHC 6.2.2 produced by the chain (mhs-built,
then self-compiled to a fixed point) builds GHC 6.6 from its source tarball,
unregisterised via C on x86-64, with a 69-line patch (perl version check,
-threaded only with GHCi, rts cc-options, build.mk) and four helper packages
on the 6.2.2 side (parsec compiled from 6.2.2's own tarball; unix, lang,
util, text, data as empty packages). Both stages link and their compiled
programs run. Inputs not from the chain: the tarball's pre-generated
Parser.hs/Lexer.hs/ParserCore.hs, and the host C toolchain as before.
