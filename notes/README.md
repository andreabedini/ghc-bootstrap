# notes

How I found the chain, kept as evidence; [`DECISIONS.md`](../DECISIONS.md) cites these
files. The phases are the phases of my original plan (see
[How I found the route](../README.md#how-i-found-the-route)). Phases 0 to 3 are
about the first chain, which used GHC 4.08.2 as its compiler and which I
retired at [D42](../DECISIONS.md#d42--where-it-stands-64-bit-assumptions-in-a-1999-runtime). Nothing here is an input to the Nix build.

| Directory | What it holds |
|---|---|
| `phase0/` | the seed: Hugs built from source, MicroHs bootstrapped from it, and the comparison with MicroHs's shipped C ([`FINDINGS.md`](phase0/FINDINGS.md), `try.sh`, the pattern-guard tests in `tests/`); `feature-scan.py`, which scans Haskell sources for constructs a Hugs-era compiler cannot parse |
| `phase1/` | picking the target GHC: `import-inventory.py` scored 4.08.2, 5.00.2, 6.0 and 6.10.4 against what mhs accepts ([`FINDINGS.md`](phase1/FINDINGS.md)); happy under mhs ([`happy.md`](phase1/happy.md)) |
| `phase2/` | GHC 4.08.2's compiler proper (`hsc`) under mhs: patches 0001-0018 and 0022-0024, the `.hs-boot` sets converted from `.hi-boot` for 4.08.2 and for the GHC 6.0 probes (`hiboot2hsboot.py`), the cpp pipeline, the module scans ([`FINDINGS.md`](phase2/FINDINGS.md)) |
| `phase3/` | GHC 4.08.2 compiling its Prelude, `hslibs/lang` and runtime: patches 0019-0021 and 0025-0030, the build scripts, and the run that stopped at [D42](../DECISIONS.md#d42--where-it-stands-64-bit-assumptions-in-a-1999-runtime) ([`FINDINGS.md`](phase3/FINDINGS.md)) |
| `phase4/` | not phase 4 of the plan: the reproduction of the 6.2.2 compiler tree from the pristine tarball, and the provenance of every input that is not a patch ([`FINDINGS.md`](phase4/FINDINGS.md)) |
| `probes/` | the scripts of the GHC 4.08.2 and 6.0 probes ([D44](../DECISIONS.md#d44--is-ghc-6x-within-mhss-reach-measured-not-estimated)): compile the compiler with mhs in dependency order, with or without the `SLIT` change |

## The GHC 4.08.2 chain

| Stage | Result |
|---|---|
| `hsc`, GHC 4.08.2's compiler proper | builds and runs (2.2 MB) |
| `ghc/lib/std`, the Prelude | 45/45 modules to object code |
| `hslibs/lang` | 24/24 modules to object code |
| `ghc/rts`, the runtime | 52/52 (45 C files and 7 hand-written Abstract C files) |
| `cbits` | 42/42 |
| link | a 6 MB executable |
| **run** | **`main = return ()` runs and exits 0** |

A program that does I/O does not work. It reaches the buffering setup for
`stdout` and dies on a 64-bit assumption in the 1999 runtime ([D42](../DECISIONS.md#d42--where-it-stands-64-bit-assumptions-in-a-1999-runtime)).
GHC 4.08.2 targets 32-bit machines and has no entry for x86-64 at all. So
wherever "32-bit" and "correct" happened to coincide, the code is silently
wrong, and nothing selects a working alternative.
- Six such bugs were fixed ([D30](../DECISIONS.md#d30--two-more-headerencoding-warts-in-the-4082-tree), [D31](../DECISIONS.md#d31--run-ghcs-own-configure-instead-of-hand-writing-configh), [D36](../DECISIONS.md#d36--preladdrlhs-branches-on-a-macro-it-never-defines), [D42](../DECISIONS.md#d42--where-it-stands-64-bit-assumptions-in-a-1999-runtime)).
- The seventh, execution jumping into `PrelHandle_getBModezuzu_info` instead
  of its entry code, is where I stopped.

Finishing would have meant porting the 1999 runtime to a word size it was
never written for. That is why I moved the entry point to
[GHC 6.2.2](../ghc622/README.md), the first GHC that knows x86-64 exists.

### `hsc` is not a compiler you can invoke

It is the middle of a pipeline whose two ends were written in perl. Eight
separate responsibilities had to be reconstructed before it would produce a
working library:

1. `unlit`: literate Haskell, dispatched on the `.lhs` suffix
2. cpp, with the driver's exact five `-D` flags
3. `ghc-iface.lprl`: `hsc` writes only a *partial* interface
4. the shipped `PrelGHC.hi`: the primop interface is not compiled
5. `-fsimplify [ -fmax-simplifier-iterations4 ]`, never omitted, even at `-O0`
6. `{-# OPTIONS #-}` extraction: `hsc` does not read pragmas
7. `-package-name std`, which the driver *renames* to `-inpackage=std`
8. `-static`: without it the code generator emits `DLL_SRT_ENTRY`, a macro
   defined as text that cannot compile

Three of the eight are invisible from `hsc`'s own flag list. The rule I took
away from it: when something is missing, read `ghc.lprl` before concluding
anything about GHC being broken. It held for 6.2.2 too: `hsc2hs`'s flags, the
32 `-u` symbols on the link line, `-fwrapv` and `-std=gnu89` all came from
reading the Makefiles and `DriverPipeline`, not from the compiler's own help
text.

## The GHC 4.08.2 patch series

30 patches against the pristine GHC 4.08.2 source release, in
`phase2/patches` and `phase3/patches`. Applying all of them to a clean
extraction reproduces the working tree byte for byte. They fall into four
groups, and only one patch is about bootstrapping at all.

### 1. Haskell that stopped being legal (0002-0018, 0022)

GHC 4.08.2 is written in the Haskell of 1999 and compiled here by mhs, which
implements a much later language. These are not bugs in GHC; the language
moved.

| Patch | What |
|---|---|
| 0002 | `SLIT(x)` produced an unboxed string literal; rewritten to `mkFastString`, removing 2,021 of them |
| 0003 | array indexing that assumed a particular `Ix` instance |
| 0004 | base-62 encoding using non-portable arithmetic |
| 0005, 0007 | unboxed character literals, including named escapes |
| 0006 | the `Eval` class, which no longer exists |
| 0008 | `Ctype.lhs` is Latin-1; transcoded |
| 0009 | `_scc_` cost-centre annotations |
| 0010 | `UniqSupply`'s `mk_supply#` is a CAF, and mhs memoises `unsafeInterleaveIO` where GHC re-executes it |
| 0011, 0013, 0015 | nine duplicate import items, a genuine GHC bug that its own compiler tolerated |
| 0012 | Applicative-Monad Proposal instances |
| 0014, 0016 | composition `.` now parses as `OverloadedRecordDot` without spaces |
| 0017 | float bit-casts |
| 0018 | `<>` is now `Semigroup` |
| 0022 | `Char#` pattern synonym import |

### 2. C that stopped being legal (0019-0021, 0027, 0028)

1999 C meeting a 2020s compiler.

| Patch | What |
|---|---|
| 0019 | `CLOSURE_TBL` declares a table `const`, `EDCP_` declares it without; 1999 gcc accepted that |
| 0020 | `mulIntCzh` is missing a `\|\|`: dead code on 32-bit, wrong on 64-bit |
| 0021, 0027, 0028 | 33 uses of GCC's cast-as-lvalue extension, removed in GCC 4.0. Rewritten as `*(T*)&lv = v`, the standard-C spelling of what the extension meant |

### 3. x86-64, which did not exist in 1999 (0023-0026, 0029, 0030)

The most interesting group. GHC 4.08.2 has no entry for this architecture
anywhere.

| Patch | What |
|---|---|
| 0023 | `config.sub` rejects the triple outright |
| 0024 | `configure`'s platform whitelist. A real `x86_64` case was added rather than masquerading as i386. No 1999 code has an `x86_64_TARGET_ARCH` branch, so arch-specific paths correctly switch *off*, which is what unregisterised means |
| 0025 | 18 defects in the `#if WORD_SIZE_IN_BYTES == 8` sections of `Int.lhs` and `Word.lhs`, which no one had ever compiled |
| 0026 | `PrelAddr.lhs` branches on `WORD_SIZE_IN_BYTES` and includes no header at all, so it silently took the 32-bit branch and disagreed with `Word.lhs` about the representation of `Word64` |
| 0029 | `Words-1`, where `Words` is 32-bit unsigned and the loop variable is 64-bit signed: `+4294967295` instead of `-1` |
| 0030 | when `StgFloat` *is* `StgDouble`, `__encodeFloat` is never compiled but is still called. The header already aliases the decode direction and simply omits the encode direction |

Patch 0028 also carries the primop return convention. `PrimOps.hc` selects it
by asking whether STG registers are pinned to machine registers. The compiler
selects it by `MAX_REAL_VANILLA_REG`, which defaults to 8 for an unknown
platform. On x86-64 the two disagreed, so primops returned results where
nobody read them.

### 4. Bootstrapping proper (0001)

| Patch | What |
|---|---|
| 0001 | `unlit` rejects a trailing space after `\begin{code}` |

**One patch out of thirty is about bootstrapping.** The other 29 are a 1999
program meeting a 2026 toolchain and a machine word twice the size it
expects. The [6.2.2 series](../ghc622/README.md#the-patch-series) has the same
shape.
