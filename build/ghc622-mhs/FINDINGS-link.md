# Linking and running compiled Haskell: GHC 6.2.2 (mhs-built) + base + RTS on x86-64

*2026-09-10. Result: **`main = putStrLn "hello"` compiles, links, prints `hello`
and exits 0.** So do eleven other programs covering Integer/GMP, Double, GC
under 319 MB of allocation, stdin/stdout/stderr/files, exceptions and exit
codes, `forkIO`/`MVar`/`Chan`, arrays, `Data.FiniteMap`, `System.Time`,
`System.Directory`, `System.Random`, `Text.Regex`. This is the point where the
4.08.2 chain died (D42: I/O handle setup in a 64-bit runtime); with 6.2.2 the
handle layer just works. Two toolchain-class fixes were needed, one of them a
must (`-fwrapv`); one compiler bug was found and traced to a shim bug another
agent had already fixed, whose damage is confined to the interface files on
disk.*

Directory `build/ghc622-mhs`. New scripts: `build-cbits.sh`, `build-libbase.sh`,
`link.sh`. Programs and outputs: `test/` (`X.hs`, `X.hc`, `X.o`, the binary
`x`, `x.out`/`x.err`, `X.compile.log`, `X.link.log`). Nothing under the
pristine extractions was modified; no `.hi`/`.hc`/`.o` in `hcobj/` was touched.

## 1. What was built

| step | script | result |
|---|---|---|
| base cbits | `build-cbits.sh` | 9 C files + `Control/Concurrent_stub.c` -> 10 `.o`, **no errors, no patches** |
| `.hc` -> `.o` | `build-hc.sh` (now `-fwrapv`, `HCOBJ=` output dir) | 144/144 into `hcobj-wrapv/` |
| archives | `build-libbase.sh` | `lib/libHSbase.a` (144 module objects + stub, 20 MB), `lib/libHSbase_cbits.a` (9) |
| link | `link.sh X.hs` | `.hs` -> `.hc` -> `.o` -> executable, 5.9 MB |

**cbits.** `libraries/base/cbits/Makefile`: `EXCLUDED_SRCS` = `ilxstubs.c`
always, `consUtils.c` off mingw32, and the whole `regex/` directory when
`HavePosixRegex = YES` (configure set it: `build/rts622/ghc-6.2.2/mk/config.mk:757`,
glibc has `regex.h`). Flags: `-DCOMPILING_STDLIB -I<ghc/includes> -I<ghc/rts>
-I../include` from that Makefile plus the RTS's `-std=gnu89 -O -DNO_REGS
-DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=622`. Unlike the RTS (58
cast-as-lvalue sites) and 4.08.2's cbits, the 2002-vintage cbits are clean C
for gcc 16: the expected D40/D31 class did not occur, so `patches/` stays empty.
`Control/Concurrent_stub.c` is the `foreign export` stub the driver emitted
while compiling `Control.Concurrent`; the Makefile puts it in the library
(`STUBOBJS`), so `build-libbase.sh` does too.

**The link line** reproduces `DriverPipeline.staticLink`
(`ghc/compiler/main/DriverPipeline.hs:990-1080`) with `getPackageLinkOpts`
(`DriverState.hs:383-397`) expanded by hand:

```
gcc -o hello Hello.o -L$W/lib -L$R/build/rts622 \
    -lHSbase -lHSbase_cbits -lHSrts -lm -lgmp -ldl \
    -u GHCziBase_Izh_static_info ... (32 -u options) ... -u __stginit_Prelude
```

Packages in dependency order base, rts: `hs_libraries` then
`extra_libraries` of each, then the rts package's `extra_ld_opts` -- the 32
`-u` symbols of `ghc/rts/package.conf.in` (no leading underscore on
x86_64-linux), which force the base modules the RTS forward-references
(`GHCziBase_Izh_con_info`, `GHCziIOBase_stackOverflow_closure`, ...) to be
pulled from the archive. `main()` itself comes from `rts/Main.c`, already in
`libHSrts.a` as `Main.o`: it calls `startupHaskell(argc, argv,
__stginit_ZCMain)` and `rts_evalLazyIO(ZCMain_main_closure)`; the program's
`Main.o` supplies `ZCMain_main_closure`, `ZCMain_main_info` (with an SRT
pointing at `GHCziTopHandler_topHandler_closure`) and `__stginit_ZCMain`, as
`test/Main.hc` shows. `-ldl` is there because `package.conf` lists it
(`HAVE_LIBDL`); `ldd` shows only libm, libgmp and libc are actually bound.

**Undefined symbols: none.** The first link of `main = return ()` succeeded
with zero undefined references. The D41 checklist was all pre-satisfied:
`AutoApply.hc`/`StgStdThunks.hc`/`PrimOps.hc` etc. are in `libHSrts.a`
(`build/rts622/FINDINGS.md` item 4); the `__encodeFloat` gap of D41 does not
exist in 6.2.2 (`StgPrimFloat.c:104` defines `__encodeFloat` unconditionally;
`PrimOps.h:200` declares it); `Concurrent_stub.o` covers the one `foreign
export`; there is no `PrelHugs` to exclude. `-O -std=gnu89` still matters for
the D41 reason (`Stable.h` `extern inline`) and is in every recipe.

## 2. Run results

Every binary in `test/`, its exit code, and what it exercised. Outputs are in
`test/x.out` / `test/x.err`; all values were checked by hand against what GHC
should print.

| program | exit | exercised | verdict |
|---|---|---|---|
| `main` (`return ()`) | 0 | RTS init, scheduler, `ZCMain`, top handler, shutdown; `+RTS -S`: 1,024 bytes allocated, 0 GCs | ok |
| `hello` (`putStrLn "hello"`) | 0 | **handle setup, stdout buffering, write**; `+RTS -S`: 29,112 bytes allocated, 0 GCs, 1 MB | **ok -- the D42 wall is gone** |
| `gc` | 0 | `foldl'` over 2M `Int`, `product [1..3000]` (Integer/GMP, 9131 digits), `reverse` 300k; `+RTS -S`: **318,946,448 bytes allocated, 291,635,432 copied, 1210 gen-0 + 8 gen-1 collections, 80 MB max residency, 166 MB in use, 0.28 s** | ok |
| `io` | 3 (asked) | `getArgs`, `getProgName`, `getLine`, `getContents`, `IORef`, `writeFile`/`readFile`/`appendFile`/`openFile`+`hGetContents`, `hPutStrLn stderr`, `hSetBuffering`, `exitWith (ExitFailure 3)` | ok |
| `exc` | 1 | `try`/`evaluate` of `div` by zero, `head []`, `error`, missing file (`IOError` text correct), `throwIO`+`catch`+`finally`, then an uncaught `ArithException` -> `Fail: divide by zero` on stderr, exit 1 | ok |
| `conc` | 0 | 5 `forkIO` producers + 1 consumer over an `MVar`, `modifyMVar_`, `threadDelay`, `Chan` with 1000 items; sums 1525250 and 500500 | ok |
| `arr` | 0 | `Data.Array` (`listArray`, lazy self-referential fib array, `accumArray`), `Word8`/`Int8`/`Word64`/`Int64` wrap-around, `Data.Bits`, `Data.Char` (`chr 955`, `show` escapes), `Data.FiniteMap`, `reads` | ok after `-fwrapv` (see 3.1) |
| `minint` | 0 | `show (minBound :: Int)` and the `IntN` minima, `toInteger minBound` | ok after `-fwrapv` |
| `lit` | 0 | `print (2.5 :: Double)`, `truncate 1e10`, `floor (-0.5)` -- `show Double` goes through `floatToDigits`/`decodeFloat`/Integer | ok |
| `time` | 0 | the seven modules the hsc2hs agent landed: `getClockTime`/`toCalendarTime`/`calendarTimeToString`/`diffClockTimes`, `getCPUTime`, `getCurrentDirectory`/`doesFileExist`/`getDirectoryContents`/`createDirectory`/`renameFile`/`removeFile`/`removeDirectory`, `mkStdGen`/`randomR`/`randomRIO` (1000 `Double`s), `matchRegex` (POSIX `regcomp` from glibc) | ok |
| `round0` (`round (2.5::Double) :: Integer`, **compiled `-O0`**) | 0 | prints `2` | ok |
| `Arith`, `Round` (at `-O`) | -- | **do not compile**: compiler panic, section 3.2 | compiler bug |

So the RTS runs compiled Haskell: allocation, both GC generations, the
mini-interpreter's `StgRun`, `catch#`/`raise#`, MVars and the scheduler's
thread switching, blocking on a handle, `foreign import`s into cbits and libc,
GMP. Nothing 64-bit-specific misbehaved. In particular the `MBlock.h`
`HEAP_ALLOCED` hack (low 32 bits of the address index a 4096-entry byte map,
`build/research-6.2-x86_64.md` item 2) held up through 1218 collections and
166 MB of heap: with `mmap` handing out contiguous megablocks near
0x7f..00000000 the low 32 bits are effectively linear, and a false positive
needs a *static* closure whose low 32 bits land on a heap megablock, which for
a 6 MB non-PIE executable near 0x400000 does not happen. It is still a hack
and still dies after 4 GB of address space; the 6.4 backport is not needed yet.

## 3. Fixes and findings

### 3.1 `-fwrapv` is mandatory for every `.hc` compile (fixed)

`arr` printed `minBound :: Int64` as `-0`. The literal was fine
(`GHC/Base.hc:2535` has `(-9223372036854775807-1)`, and `minInt == minBound`
is `True` at run time); the bug is in `GHC/Show.lhs:261-268`:

```haskell
itos n# cs
    | n# <# 0# = let n'# = negateInt# n#
                 in if n'# <# 0# -- minInt?
                    then '-' : itos' (negateInt# (n'# `quotInt#` 10#)) ...
                    else '-' : itos' n'# cs
```

The `minInt?` test relies on two's-complement wrap of `negateInt#`. In the
generated C that is `-(n)` on a signed `long`, and gcc 16 at `-O` applies the
C rule that signed overflow does not happen: from `n < 0` it concludes
`-n > 0` and deletes the test. The `else` branch then runs `itos'` on
`minBound`, `chr# (ord# '0'# +# n#)` yields a `Char` whose low byte is `'0'`,
and the byte-oriented `hPutStr` of 6.2.2 writes that byte: `-0`. Every
`show` of a minimal `Int`/`IntN` was wrong; nothing else in the test set was
visibly affected, but any Haskell code that reasons about overflow with
`Int#` is at risk in the same way.

Fix: `-fwrapv` in `build-hc.sh` and in `link.sh`'s `.hc` compile. This is
the same 2026-toolchain class as D40 (gcc 3.x did not exploit this
particular undefined behaviour), and it is what GHC itself did later: from
6.8 the driver passes `-fwrapv` to gcc for every via-C compile.
Verified twice: recompiling only `GHC/Show.hc` with `-fwrapv` and linking
that object ahead of the library fixed `minint`; the full rebuild into
`hcobj-wrapv/` reproduces the fix with every other test unchanged.

`hcobj/` (compiled without `-fwrapv`) was left as it was, per the brief;
`HCOBJ=$PWD/hcobj-wrapv sh build-hc.sh` and `HCOBJ=$PWD/hcobj-wrapv sh
build-libbase.sh` are what `lib/` was built from. Once the other agents are
done, plain `sh build-hc.sh && sh build-libbase.sh` regenerates `hcobj/` and
`lib/` with the right flags. The RTS (`build/rts622`) was compiled without
`-fwrapv`; its own `.hc` files and C do the same kind of arithmetic
(`mulIntMayOflo`, Integer ops), so `build-rts.sh` should get the flag too --
not done here, no failure was traced to it.

### 3.2 Compiler bug: conflated worker/wrapper names in interface files (root cause found, already fixed upstream of me)

`main = print (round (2.5 :: Double) :: Integer)` at `-O` panics the
compiler:

```
panic! (the `impossible' happened, GHC version 6.2.2):
        Missing alternative
    2.5
    (GHCziFloat.Dzh {- d 66 -}, [ww_a3nk], GHCziFloat.zdwzdsround {- v roc -} ww_a3nk)
```

`CoreUtils.findAlt` prints a `LitAlt` as the literal, so the simplifier was
matching the *unboxed* scrutinee `2.5##` against a `D#` alternative.
`-ddump-inlinings` shows why: the last inlining before the panic is of
`GHCziFloat.zdwzdsround` -- the **worker** `$w$sround :: Double# -> Integer`
-- with the **wrapper's** unfolding `\w -> case w of D# ww -> $w$sround ww`.
And `--show-iface GHC/Float.hi` (in `test/Float.iface.txt`) shows two
top-level signatures named `$w$sround`, lines 447 and 455: the worker, and
the wrapper `$sround :: Double -> Integer` printed under the worker's name.
Its `Int` twin is correct (`$sround1`/`$w$sround1`). The reader assigns one
Name per `(module, occ)`, so the importer gets one Id carrying both
unfoldings, and whichever wins is wrong for one of the call sites. At `-O0`
interface pragmas are ignored and the program compiles and prints `2`.

The `.hc` is *not* affected: `GHC/Float.hc:4329` defines
`GHCziFloat_zdsround_closure` and `:4094` `GHCziFloat_zdwzdsround_info`,
distinct as they should be. The corruption is in the `.hi` writer:
`utils/Binary.hs:592,683` keys its string dictionary by `getUnique` of the
`FastString`, and under the shim two different strings had received the
**same unique**. `ghc622/shims/FastString.hs` (`intern`) now
carries the diagnosis agent's fix and explanation: `mkWorkerOcc` builds
`"$w" ++ occNameString occ`, forcing that string re-enters `intern` for
`occ`'s own FastString, and the outer call's table snapshot then overwrote
the inner insert -- so `$sround` and `$w$sround` shared a unique. GHC's real
`mkFastString` hashes the whole string before touching its table, so it never
had this re-entrancy. The shim was fixed at 09:51; the `ghc` binary here is
from 07:12 and **every `.hi` in `libraries/base` was written by the old
binary**. Which of them are damaged is measurable: `--show-iface` on all 144
and look for a repeated top-level name (`test/ifaces/*.txt`,
`test/ifaces/DUPLICATES.txt`):

**5 of 144 interfaces are damaged** (every `--show-iface` succeeded, so this
is the complete list):

| module | top-level names that appear twice |
|---|---|
| `GHC.Float` | `$w$sround`, `$w$s$dmatan2` |
| `GHC.List` | `$w$smaximum`, `$w$sminimum` |
| `GHC.Real` | `$s$fEnumRatio`, `$s$fEqRatio`, `$s$fFractionalRatio`, `$s$fNumRatio`, `$s$fRealRatio` |
| `Data.Array.Diff` | `$w$s$fHasBoundsIOToDiffArray` |
| `Text.Html` | `$fHTMLTABLEHtml`, `$s$fADDATTRS(->)`, `$w$sbeside` |

Each is a specialisation (`$s`) or worker (`$w`) pair, i.e. exactly the
`mkWorkerOcc`/`mkSpecOcc` "prefix ++ occNameString" re-entrancy. The other
139 interfaces, including everything `Prelude`, `System.IO`,
`Control.Exception` and `Control.Concurrent` re-export, are clean, which is
why every program above compiled at `-O` except the two that touch
`round :: Double -> Integer`.

Consequences and what to do:

- Importers of a damaged interface that inline a conflated pair at `-O` get
  a panic (this case) or a simplifier loop / heap exhaustion (the diagnosis
  agent's finding on `Data.Complex`, `Data.Graph`, `System.Console.GetOpt`;
  my `RoundArg.hs`, which uses `round` on a non-literal, died with `ERR:
  heap exhausted` the same way). The `.o` code in `lib/libHSbase.a` is
  correct and all run results above stand.
- The fix is to relink `ghc` with the fixed shim (`build.sh`, ~10 min) and
  recompile at least the modules whose interfaces are damaged and everything
  downstream of them that inlined them -- in practice a fresh base pass.
  Not done here: it is the other agents' pipeline.
- Until then, user programs must avoid the damaged pairs at `-O` or compile
  with `-O0` (`OPT=-O0 sh link.sh ...`), which `round0` demonstrates.

### 3.3 Small things worth knowing

- `link.sh` needs paths relative to `build/ghc622-mhs` (`sh link.sh
  test/X.hs [out]`); `OPT`, `VERB`, `HCFLAGS`, `CFLAGS`, `LDFLAGS`, `EXTRA_O`
  are honoured.
- 6.2.2's `+RTS -S` writes to `<prog>.stat`, not stderr (`test/*.stat`).
- An uncaught exception exits 1 with `Fail: <exception>` on stderr (the
  6.2.2 top handler's wording), and `exitWith` codes propagate.
- 6.2.2's base API differences bit my first drafts, not the chain:
  `Control.Monad` has no `forM_`/`forever`, `Data.Bits` no `popCount`,
  `Text.Regex` no `subRegex`/`splitRegex`, `System.IO` exports a `try` that
  clashes with `Control.Exception.try`, and `Prelude.catch` must be hidden.

## 4. Files

New: `build-cbits.sh`, `build-libbase.sh`, `link.sh`, `cbitsobj/`,
`hcobj-wrapv/`, `lib/`, `test/` (12 programs, binaries, outputs, logs,
`Float.iface.txt`, `Round.core.log`, `Round.inl.log`, `ifaces/`,
`rv/` variant sources), this file. Edited: `build-hc.sh` (`-fwrapv`, `HCOBJ`).
Not edited: anything under `libraries/base`, `hcobj/`, `build/rts622`,
DECISIONS.md, README.md.
