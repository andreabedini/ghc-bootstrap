# Phase 3 findings — GHC compiling the Prelude

Started 2026-09-02, continuing from [`../phase2/FINDINGS.md`](../phase2/FINDINGS.md).

## Result so far: GHC emits C

The bootstrapped `hsc` has compiled `PrelBase` — the core module of the Haskell
Prelude — all the way to Abstract C:

```
build/ghc-mhs/lib/PrelBase.hc   230,611 bytes of C
build/ghc-mhs/lib/PrelBase.hi    36,649 bytes of interface
```

The C is the real thing — GHC's unregisterised via-C output, ready for gcc:

```c
START_MOD_INIT(__init_PrelBase)
REGISTER_IMPORT(__init_PrelErr);
INFO_TABLE(c3EF_info,c3EF_entry,0,1,FUN,static ,IF_,0,0);
IFN_(c3EF_entry) { FB_ ARGS_CHK(1); R2.p=(P_)(*Sp); Sp=Sp+1; JMP_(c3EF_fast1); FE_ }
SET_STATIC_HDR(PrelBase_zddmfail_closure,PrelBase_zddmfail_info,0,,EI_)
```

with 712 info-table/closure definitions and Z-encoded names
(`PrelBase_append_closure`, `PrelBase_asTypeOf_info`, ...). The interface file
is GHC 4.08's own format:

```
__interface "Main" PrelBase where
__export PrelBase Bool{False True} Char{Czh} Eq{zsze zeze} Functor{fmap} ...
```

So the chain now reaches: **C compiler + Hugs source -> mhs -> hsc -> C for the
Haskell Prelude.**

## The pipeline

`hsc` is GHC's *compiler proper*. The perl driver used to unlit and preprocess
before invoking it, so `phase3/compile-lib-module.sh` reproduces that:

```
unlit   (GHC's own ghc/utils/unlit/unlit.c, built with -fpermissive)
  -> cpphs --strip --linepragma      (built by mhs from MicroHs's source)
  -> hsc <file> [flags]              (built by mhs from GHC's source)
```

Four things had to be right, none of them obvious:

| | |
|---|---|
| filename **first** | `CmdLineOpts.src_filename` takes `argv`'s head and panics `no filename` if it begins with `-` |
| `--linepragma` | cpphs's default `#line` directives are a parse error for `hsc`; it wants `{-# LINE #-}` |
| `PrelGHC.hi` | GHC's own Makefile rule is literally `cp PrelGHC.hi-boot PrelGHC.hi` — the primop interface is shipped, not compiled |
| `-olang=C` | without it `codeOutput` is a no-op and only the `.hi` appears |

`unlit.c` is K&R C and needs `-fpermissive` on GCC 16 — the same finding Phase 0
recorded for Hugs, from the other end of the chain.

## A harness bug worth recording

The first run produced a `PrelBase.hi` of *exactly* 4096 bytes and no `.hc`,
which looked like a compiler failure. It was mine: the script piped `hsc`
through `head -20`, and `hsc` emits dozens of `pprTrace` lines, so `head` exited
and **SIGPIPEd the compiler mid-write**. One block of a buffered interface file
had made it to disk.

The tell was the size: exactly 4096 is a block, not a number a program chooses.

## Diagnostics that are not errors

`hsc` prints two kinds of trace while compiling `PrelBase`:

- `topCoreBindsToStg` — `CoreToStg.lhs:212`, a `pprTrace` for top-level
  bindings that become `NoBindF` (indirections such as `zl10 = zl9`). GHC's own
  comment: "We might want to revisit this decision".
- `ifaceBinds not found` — for derived helpers like `con2tagzuBoolzh1`.

Both are GHC's own diagnostics and neither stops compilation. Whether a real
GHC 4.08 emits the same set on this module is **unverified**, and worth checking
before trusting the output — see Open questions.

## The generated C compiles

gcc accepts it. `PrelBase.hc` builds to a 492,760-byte ELF object with 1,566
symbols in GHC's expected shape:

```
T __init_PrelBase              D PrelBase_append_closure
T PrelBase_append_entry        R PrelBase_append_info
T PrelBase_asTypeOf_entry      D PrelBase_asTypeOf_closure
```

so the chain is now demonstrated end to end:

```
C compiler + Hugs source -> mhs -> hsc -> PrelBase.hc -> gcc -> PrelBase.o
```

Three things were needed beyond the compile itself:

- **`config.h` had to grow.** The version generated for the *compiler* needed
  only `WORDS_BIGENDIAN` and `LEADING_UNDERSCORE`; the RTS headers additionally
  want the full `SIZEOF_*` set (including the `UNSIGNED_` variants) and a few
  `HAVE_*` probes. `phase2/mkconfig.sh` now emits both sets.
- **`-DNO_REGS -DUSE_MINIINTERPRETER`** for the unregisterised build, and
  `-include Stg.h`, which the perl driver used to supply.
- **A `const` mismatch in GHC's own headers** (`phase3/patches/0019`):
  `CLOSURE_TBL` defines `const StgClosure *lbl[]` while `EDCP_` declares the
  same table without the `const`. 1999 gcc accepted it; modern gcc calls it a
  conflicting type. The definition is the authority, so the declaration was
  changed to match.

## Open questions

1. **Is the object code *correct*?** It compiles and has the right symbols, but
   nothing has linked or run it. Correct-looking output has already been wrong
   twice in this project (D24).
2. **Do the traces match a real GHC 4.08?** If ours emits more `NoBindF` cases
   than the original, something upstream differs.
3. The remaining 46 modules of `ghc/lib/std`, then `hslibs`, then closing the
   loop.

---

## The Prelude builds: 20 → 45 modules

Compiling `PrelBase` alone left 25 of the 45 `ghc/lib/std` modules failing.
Grouping the failures by message showed most were cascades behind two roots.

### The driver always runs the simplifier

Every module doing a `_ccall_` died with

```
cgPanic: lookupBindC: no info for $wccall_d3I3
```

`DsForeign.lhs:154` desugars a `_ccall_` into a `$wccall` worker plus a wrapper
marked `mkInlineMe`; the code generator only ever expects the inlined form. The
inlining is the simplifier's job, and `ghc/driver/ghc.lprl` never lets it be
skipped — its *no-optimisation* flag list still contains

```perl
'-fsimplify', '[', '-fmax-simplifier-iterations4', ']'
```

I had been running `hsc` with an empty Core-to-Core pass list, which no real GHC
invocation ever does. Supplying the pass took the build from 20/45 to 38/45.

### The driver extracts `{-# OPTIONS #-}` pragmas

`hsc` does not read pragmas. `ghc.lprl:2778` (`check_for_source_options`) scans
the de-litified source and appends what it finds to the command line. 31 of the
45 std modules carry `{-# OPTIONS -fno-implicit-prelude #-}` this way, and 15
carry `-#include` naming a C header.

Reproducing that scan fixed `Time` (`deriving (Eq, Ord)` with no `Eq` in scope),
`IO` (`readIO` not in scope), and `PrelHugs`. See DECISIONS.md D29 for the wrong
turn taken first — a positional rule that got six modules wrong *without failing*.

### Two more 1999-isms in the C

- `PrimOps.h:648` writes `(P_)(((StgMutVar *)(a))->var)=(v)` — a cast on the
  left of an assignment, which was a GCC extension until 4.0.
- `CPUTime.lhs` holds a stray `0xA0` in a comment. It is the only non-ASCII file
  in `ghc/lib/std`, and it is not valid UTF-8; mhs's reader is UTF-8-only and
  aborts with `ERR: getb_utf8`. The pipeline now transcodes Latin-1 when the
  bytes do not already decode as UTF-8.

### `config.h`, and why the last three failures were good news

`Time`, `Directory` and `PrelHugs` then failed in gcc on

```
cbits/timezone.h:78: #error Dont know how to get at timezone name on your OS.
```

They failed *because* `-#include` had started working. Before that the headers
were never included, so the foreign-call prototypes were absent — and on x86-64
an implicitly-declared function returning a pointer is truncated to `int`. The
state that looked healthy was the broken one.

The fix was to stop hand-writing `ghc/includes/config.h` and run GHC's own
`configure`, which ships with all 177 probes. Getting a 1999 autoconf to run
needed four accommodations (x86-64 unknown to `config.sub` and to `configure`'s
platform whitelist; pre-C99 probe programs; and a version test that compares
`1.19.5 < 1.6` as strings). All four are recorded in DECISIONS.md D31.

It also caught a live bug in my hand-written file: `#define LEADING_UNDERSCORE 0`,
read by `MachMisc.lhs:62` as `#ifdef`, is *true*.

## Scope of what remains

The compiler imports 44 modules from outside `ghc/compiler`: 20 from
`ghc/lib/std` and 24 from `hslibs` — all of the latter in `hslibs/lang`, the
transitive closure of `Addr`, `Bits`, `ByteArray`, `Exception`, `Foreign`,
`GlaExts`, `IOExts`, `Int`, `MutableArray`, `NativeInfo`, `ST` and `Word`. None
of the other eleven `hslibs` packages is needed; `SocketPrim` and `BSD` appear
in `Main.lhs` but sit behind `#if REPORT_TO_MOTHERLODE`, which is off.

So the remaining path is 24 library modules, the RTS (36 C files), and a link.

---

## The libraries, the runtime, and a program that runs

### Final state

```
ghc/lib/std    45/45 modules -> .hi + .hc + .o
hslibs/lang    24/24 modules -> .hi + .hc + .o
ghc/rts        52/52 objects (45 .c + 7 hand-written .hc)
cbits          42/42 objects
link           6MB executable
run            main = return ()  ->  exits 0
```

`main = return ()` running to a clean exit is the first evidence in this project
that the generated code is executable at all. Everything before it was about
compilation succeeding.

### The 64-bit sections of hslibs/lang had never been compiled

`Int.lhs` and `Word.lhs` each carry a `#if WORD_SIZE_IN_BYTES == 8` section — 97
and 129 lines — that opens only on a 64-bit platform. GHC 4.08.2 lived on 32-bit
x86, so on the machines that mattered these were skipped entirely, and they had
rotted: eighteen distinct defects, from a constructor missing its `#` to
`complement` implemented as arithmetic negation.

Neither module can be avoided: `PrelRules.lhs` imports `Word64` and `Ctype.lhs`
imports `Int32`.

Every repair was taken from the same file's own 32-bit code rather than
invented — the `Bits Int32` instance supplied the correct `complement`, the
`Bits Word32` instance the `rotate` parenthesisation, `Eq Int32` the `==#`/`/=#`.
That is what kept the work mechanical rather than a matter of taste. Full list
in DECISIONS.md D34 and D38.

### Linking needed four things the object files did not imply

1. The RTS's seven hand-written `.hc` files (`SRCS_RTS_HC`). Without them:
   22,619 undefined references. With them: 9.
2. `hslibs/lang`'s own cbits — one file, `PackedString.c`.
3. Excluding `PrelHugs.o`, which `ghc/lib/std/Makefile:38` filters out of
   `LIBOBJS` unconditionally.
4. `-O`, which is required rather than preferred: `Stable.h` defines
   `deRefStablePtr` and friends `extern inline` with no out-of-line copy
   anywhere, so every call must be inlined or the link fails.

Point 4 has a matching trap on the other side. Without `-std=gnu89` the link
fails instead with *multiple* definitions of the same functions, because C99
inverted the meaning of `extern inline`. Both failures come from the same two
lines of header, and they point in opposite directions.

### Debugging one putStrLn

Three more 64-bit bugs, each found from a segfault and a backtrace:

- **Primop returns went to the wrong place.** `PrimOps.hc` chooses its
  unboxed-tuple return convention by asking whether STG registers are pinned to
  machine registers; the compiler chooses by `MAX_REAL_VANILLA_REG`, which
  defaults to 8 for an unknown platform. They disagreed. Confirmed from both
  sides before touching anything: `cd3v_ret` reads `R1.p`, and `RET_P` under
  "0 Regs" expands to `PUSH_P(1,a)`.

- **A loop counter underflowed into four billion iterations.**
  `Updates.hc:386` computes `Words-1` where `Words` is `nat` (32-bit unsigned)
  and the loop variable is a 64-bit `long`. At `Words == 0` that is
  `+4294967295` instead of `-1`. On 32-bit both are 32 bits, the value is `-1`,
  and the loop is correctly skipped.

- **Open:** execution jumps into `PrelHandle_getBModezuzu_info` rather than its
  entry code.

### What debugging this taught

Every one of these was found by reading evidence rather than reasoning from a
theory. The register-convention bug was settled by printing the ForeignObj's two
words and seeing the data pointer sitting correctly at offset 8 while the caller
read zero — which ruled out the layout theory and pointed at the return path.
The underflow was settled by `rax = 0x7fffffff8`, which is exactly
`0xFFFFFFFF * 8`, and only one expression in the function could produce it.

The one time a theory was allowed to run ahead — assuming the `getBufferMode`
NULL was pointer truncation from a missing prototype — it was wrong, and the
prototype turned out to be present all along.
