# hsc2hs built with mhs; the four `.hsc` modules of base compiled

*2026-09-10. Result: GHC 6.2.2's `hsc2hs` (`ghc/utils/hsc2hs/Main.hs`, "version
0.65") builds with mhs in about a minute; run with `libraries/base/Makefile`'s
flags it turns `System.CPUTime`, `System.Time`, `System.Posix.Signals` and
`Text.Regex.Posix` into `.hs`, and the mhs-linked GHC 6.2.2 compiles those four
plus their importers `System.Directory`, `System.Random`, `Text.Regex`: **7/7 to
`.hi` + `.hc`, 7/7 `.hc` to `.o`**. base is now at 144 of 147 rows (137 + 7);
only `Data.Complex`, `Data.Graph`, `System.Console.GetOpt` remain.*

Directory `build/hsc2hs-mhs`: `build.sh` (mhs build), `hsc2hs-bin` (the
program), `hsc2hs` (driver script), `template-hsc.h`, `shims/System.hs`,
`ghc/utils/hsc2hs/{Main.hs,Config.hs,...}` + `ghc/includes` symlink (tarball
layout, so Main.hs's `#include "../../includes/config.h"` resolves unchanged),
`hsc-order.txt`, `build-hc-hsc.sh`, `run-hsc.log`. Results:
`build/ghc622-mhs/base-results-hsc.tsv` (also appended to `base-results.tsv`).

## 1. Building hsc2hs

```
cd ghc622/hsc2hs/src
mhs -XCPP -D__GLASGOW_HASKELL__=622 -i. -i../../../shims -i ghc622/shims-h98 Main -o hsc2hs-bin
```

- `-D__GLASGOW_HASKELL__=622` (not the compiler build's 408): Main.hs imports
  `System.Console.GetOpt` when `>= 504` and the hslibs-era `GetOpt` otherwise;
  MicroHs ships the former. Nothing else in the file tests the value.
- `Config.hs` is what the Makefile's `$(CONFIG_HS)` rule writes from
  `mk/config.mk`: `cDEFAULT_TMPDIR="/tmp"`, `cGCC="gcc"`, `progNameSuffix=""`,
  `pathSep='/'`. Only `progNameSuffix` and `pathSep` are used.
- `shims/System.hs`: Haskell 98's `System` also exports
  `system :: String -> IO ExitCode`; `ghc622/shims-h98/System.hs` re-exports
  only `System.Environment` + `System.Exit`. The local shim adds `system` from
  MicroHs's `System.Process`, first on `-i`. The shared shim is untouched.
- `ghc622/shims-h98` supplies `Directory`, `Monad`, `Char`, `List`, `IO`.

### Edits to Main.hs (copy; all marked `-- mhs`; 17 changed lines)

One thing only: the `Parser` newtype's class instances. The 2004 file defines
`return` and `fail` inside `instance Monad Parser` and `mzero`/`mplus` in
`instance MonadPlus Parser`; mhs's Prelude has the post-AMP layout, where
`return` is not a `Monad` method ("superflous instance binding" at line 184)
and `MonadPlus` needs `Alternative`. The copy adds `instance Functor`,
`instance Applicative` (`pure` = the old `return`), `instance MonadFail`
(the old `fail`), `instance Alternative` (`empty`/`<|>` = the old
`mzero`/`mplus`), and points `MonadPlus` at them; plus
`import Control.Applicative (Alternative(..))`. Behaviour is identical.

## 2. The driver script and the C compiler

`hsc2hs` is `hsc2hs.sh` with the Makefile's `SCRIPT_SUBST_VARS` filled in for
the in-place layout (`ghc/utils/hsc2hs/Makefile`, `INSTALLING=0`):

```
--template=<here>/template-hsc.h --cc=gcc --ld=gcc
--cflag=-std=gnu89                                   (ours; see below)
--cflag=-D__GLASGOW_HASKELL__=622 -I<build/ghc-6.2.2-run1/ghc/includes>
```

`template-hsc.h` is the tarball's, unmodified. `ghc/includes` is our copy with
the x86_64 `config.h` + the `HTYPE_*` block (ghc622-mhs FINDINGS gap 7), the
same one the compiler run used, so `#{type ...}`/`HsFFI.h` see the same
widths the `.hi` files were built with.

**The one addition: `--cflag=-std=gnu89`.** hsc2hs compiles a generated C
program that `#include`s `HsBase.h`, and `libraries/base/include/HsBase.h`
defines `INLINE int __hscore_s_isblk(m) { ... }` (K&R parameter lists, lines
208-211). gcc 16 (like gcc >= 14) makes implicit `int` an error in its default
C23 mode, so the first two modules died in the C step. `-std=gnu89` is exactly
the mode `build-hc.sh`/`build-rts.sh` already use for GHC's own `.hc` output.
`HSC2HS_CFLAGS` in the environment overrides it. This is the same
2026-toolchain class as D31/D40 and gap 7, not an hsc2hs or MicroHs problem.

Everything else in the pipeline is stock: `gcc -c` the `X_hsc_make.c`, `gcc`
link, run it with stdout to `X.hs`, delete the three intermediates. None of
the four modules uses `#def`, so no `_hsc.c`/`_hsc.h` files are produced
(`find libraries/base -name '*_hsc*'` is empty).

## 3. Generating the four modules

`mk/suffix.mk`: `%.hs : %.hsc  ->  $(HSC2HS) $(HSC2HS_OPTS) $<`, with
`HSC2HS_OPTS` = `SRC_HSC2HS_OPTS` = `-Iinclude -I$(FPTOOLS_TOP)/ghc/includes`
(base's Makefile) + `-I.` (`mk/package.mk`); `-Icbits/regex` is off because
`mk/config.mk` has `HavePosixRegex = YES` (glibc's `regex.h`). So, from
`build/ghc622-mhs/libraries/base`:

```
build/hsc2hs-mhs/hsc2hs -Iinclude -I<ghc/includes> -I. System/Time.hsc      (etc.)
```

Output lands next to the source (`System/Time.hs`, ...), which is where
`run-base.sh` looks. The four `.hs` start with the expected
`{-# OPTIONS -#include "HsBase.h" #-}` / `-#include "Signals.h"` /
`-#include "regex.h"` pragmas and `{-# LINE n "Time.hsc" #-}` markers, and
the probed values are the right ones for x86_64 glibc (`struct timeval`
`tv_usec` at offset 8, `tm_zone` at 48, `REG_EXTENDED` = 1, `REG_ICASE` = 2,
`clockTicks` via `sysconf(_SC_CLK_TCK)`).

## 4. Compiling them

`FRESH=0 MODTIMEOUT=900 sh build/ghc622-mhs/run-base.sh build/hsc2hs-mhs/hsc-order.txt`
under `ulimit -v 6000000`, i.e. the same `-fglasgow-exts -cpp -Iinclude
-#include HsBase.h -funbox-strict-fields -package-name base -O -C` as the
137. All seven at plain `-O`, no `-fno-strictness` retry needed:

| module | time | `.hc` lines | `.o` bytes |
|---|---|---|---|
| `System.CPUTime` | 15 s | 586 | 22208 |
| `System.Time` | 89 s | 34848 | 1155752 |
| `System.Posix.Signals` | 21 s | 6189 | 220224 |
| `Text.Regex.Posix` | 15 s | 1195 | 38488 |
| `System.Directory` | 30 s | 9225 | 313664 |
| `System.Random` | 23 s | 7553 | 263200 |
| `Text.Regex` | 4 s | 325 | 13112 |

`build-hc-hsc.sh` compiled the seven `.hc` with `build-hc.sh`'s exact recipe
into `build/ghc622-mhs/hcobj/` (only these seven objects were written; the 137
existing ones were not touched). `System_Time.o`'s undefined symbols are base's
own closures/info tables, RTS entry points (`integer2Intzh_fast`,
`newPinnedByteArrayzh_fast`, `raiseIOzh_fast`) and libc's `gettimeofday`,
`gmtime_r`, `localtime_r`, `mktime` -- the shape the other objects have.

## 5. `GHC.PrimopWrappers`

Already dealt with in the compiler run (ghc622-mhs LOG.md "Result"):
`build/ghc622-mhs/libraries/base/GHC/PrimopWrappers.hs` is byte-identical to
`build/gen622/genprimopcode/genprimopcode --make-haskell-wrappers <
build/gen622/prelude/primops.txt` (checked with `diff`), which is
`libraries/base/Makefile`'s rule for the non-`BootingFromHc` case, and its
`.hi`/`.hc`/`hcobj/GHC_PrimopWrappers.o` exist (10 s, 5324 lines). The
`base-results.tsv` row still said FAIL from the ordered pass (the file was
still the Makefile's `touch`ed empty one then); corrected to OK. It is not
GHCi-only: it is an ordinary module of base whose `.o` goes into `libHSbase.a`
(the wrappers are what `GHC.Exts`-level code calls for out-of-line primops).

## 6. Bookkeeping

- `base-results.tsv`: 7 rows appended by `run-base.sh` (FRESH=0), the
  PrimopWrappers row corrected, and the three stale `FAIL` rows for
  `System.Directory`/`System.Random`/`Text.Regex` removed (superseded).
  Now 144 OK / 3 FAIL. `base-results-hsc.tsv` has this run's rows alone.
- New files in the tree: `System/{CPUTime,Time}.hs`,
  `System/Posix/Signals.hs`, `Text/Regex/Posix.hs` (generated), their
  `.hi`/`.hc`, and `.hi`/`.hc` for the three importers; seven `.o` in `hcobj/`.
- Tarball extractions untouched; the only edited source is the Main.hs copy
  under `ghc622/hsc2hs/src`.

## 7. Open

Nothing from this task. The three base modules that were still open when
this was written (`Data.Complex`, `Data.Graph`, `System.Console.GetOpt`) were
closed the same day: a FastString unique collision in the shim, not a
compiler or module problem (`build/ghc622-mhs/diag/FINDINGS.md`, D48). base
is 147/147; the seven modules above are part of that count and were
recompiled in the rebuild.
