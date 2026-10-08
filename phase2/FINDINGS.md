# Phase 2 findings — building the chain

Running log. Started 2026-09-02. Decisions are indexed in
[`../DECISIONS.md`](../DECISIONS.md); this file records *state*: what exists,
what runs, what is still assumed.

## The chain as designed

```
  C compiler + Hugs source                                    [VERIFIED, phase 0]
        |
        v
  mhs  (MicroHs, self-hosting, fixpoint + DDC verified)       [VERIFIED, phase 0]
        |
        +-- cpphs            (from MicroHs's generated/cpphs.c)      [BUILT]
        |
        +-- happy-mhs        (happy 1.19.5 + common/shims)           [VERIFIED]
        |        |  gen2 == gen3 byte-identical; happy-ghc is out
        |        |  of the trusted base (D7 discharged, D14)
        |        |
        |        +-- GHC 4.08.2's Parser.hs + ParseIface.hs          [GENERATED]
        |            18,918 lines, produced in-chain
        |
        v
  GHC 4.08.2 compiler source + ghc-on-mhs shims               [BUILDS + RUNS]
        |
        v
  hsc: 5.9MB of C -> a 2.2MB binary that runs and parses,     [RUNS]
       renames and reports GHC's own diagnostics
        |
        v
  GHC's own libraries (ghc/lib/std, 47 modules) as .hi        [NOT STARTED]
        |
        v
  GHC 4.08.2 emitting C for itself, unregisterised            [NOT STARTED]
        |
        v
  native self-hosting GHC                                     [NOT STARTED]
```

## Status

| artifact | state | where |
|---|---|---|
| `mhs` | built, fixpoint-verified | `MicroHs/bin/mhs` |
| `hmhs` (Hugs-derived) | built, byte-identical output to `mhs` | `MicroHs/bin/hmhs` |
| `cpphs` | built from MicroHs's shipped C | `MicroHs/bin/cpphs` |
| `happy-ghc` 1.19.12 | used once as a generator; **now discharged, no longer needed** | `build/tools119/happy-1.19` |
| happy 1.19.5 portable parsers | generated, zero GHC-isms | `build/happy-1.19.5/src/{Parser,AttrGrammarParser}.hs` |
| GHC 4.08.2 portable parsers | **regenerated in-chain** by `happy-mhs2`, 18,918 lines | `build/ghc-parsers/` |
| `ghc-on-mhs` shims | 16 modules, all typecheck under `mhs` | `common/shims/` |
| `happy-mhs` | **built, runs, fixpoint-verified** | `build/happy-mhs/happy-mhs2` |

## Established by experiment, not assumed

1. **`mhs` compiles happy's hand-written source.** Every module that does not
   transitively import a generated parser compiles; see
   [`../phase1/happy.md`](../phase1/happy.md).
2. **No shipped happy parser is usable** — all are GHC-template output with
   unboxed `Addr#` string literals, which is lexical and unshimmable (D5).
3. **happy 1.19 accepts GHC 4.08.2's 1999 grammar** — 21 shift/reduce conflicts,
   which is normal for it, and the output is portable Haskell (D10).
4. **`mhs` accepts MagicHash identifiers** and has `Unsafe.Coerce`, so
   `unsafeCoerce#` is a rename, not a blocker. Only unboxed *literals* stop it.
5. **MicroHs has more of `base` than its module names suggest** — `Mhs.Array` is
   a complete `Data.Array`, `Mhs.MutArr` a real mutable array. Several apparent
   gaps were aliases (corrected in `../phase1/FINDINGS.md`).

## Open risks

- **`Data.Set`/`Data.Map` shims are O(n).** Fine for happy; almost certainly not
  fine for GHC's compiler, which leans on `FiniteMap` heavily. Expect to need a
  real balanced-tree implementation before Phase 3.
- **`UArray` is boxed** in the shim. Correct, but memory-hungry at GHC's table
  sizes.
- **The GHC-built happy is still in the trusted base** until the fixpoint check
  in D7 runs.
- **Nothing has yet compiled a line of GHC.** Every finding so far is about the
  tools GHC needs, not GHC.

## Milestone: happy is bootstrapped (2026-09-02)

```
happy-mhs2 parser/Parser.y      ->  11,212 lines   3 unused terminals, 21 s/r conflicts
happy-mhs2 rename/ParseIface.y  ->   7,706 lines   2 unused rules, 17 unused terminals
```

The conflict counts match what the GHC-built happy reported, so the two agree on
the grammar. `gen2 == gen3` byte-identical for happy's own two parsers
(1,313 and 931 lines) means the chain reproduces its own parser generator.

**Re-verified 2026-09-02 after `Data.Map` was rewritten** from a sorted list
into a weight-balanced tree: happy rebuilt against the new shim still emits a
parser byte-identical to `gen3`. Worth doing rather than assuming — the shim
happy's fixpoint was verified against no longer existed, so the verification
would otherwise have referred to something that had been replaced.

What this buys: **the tool dependency in D4 is now satisfied from inside the
chain.** A GHC parser can be produced from `Parser.y` using nothing but a C
compiler, Hugs source, and the artifacts derived from them.

## The shim, as it grows

`common/shims/` is the embryonic `ghc-on-mhs`. Every module in it was added
because a *specific compile failed*, and the failure is recorded here so the
next person can tell a real gap from a guess.

| added | module | prompted by |
|---|---|---|
| alias | `Data.Array`, `.IArray`, `.Unboxed` | MicroHs ships this as `Mhs.Array` |
| real | `Data.Array.MArray`, `.ST` | happy's table builder; over `Mhs.MutArr`, O(1) |
| real | `Data.Set`, `Data.IntSet`, `Data.Map` | MicroHs has no `containers` |
| real | `Control.Monad.{Reader,Writer,Error,Except}` | MicroHs has no `mtl` |
| real | `Control.Monad.Trans` | so two mtl shims export *one* `lift` |
| alias | `GHC.Exts` | `unsafeCoerce#` → `Unsafe.Coerce.unsafeCoerce` |
| empty | `Control.Monad.Instances` | base module that became instance-only, then vanished |

Two additions were failures worth naming, because both are *base drift* rather
than MicroHs gaps, and Phase 2 will hit the same class repeatedly:

- **`MonadFail (Either String)`** — happy's `happyError = fail "…"` relied on
  pre-`MonadFail` mtl, where `Either e` had `fail = Left . strMsg`. Restoring
  the historical instance keeps the parse failure a `Left`; an `error`-based
  instance would have compiled and misbehaved at runtime (D12).
- **`mapWriter`** — present in every mtl, simply not yet in the shim.

The rule that fell out of this, now recorded as D12: **where MicroHs's `base`
differs from the `base` a package expects, reproduce the old behaviour in the
shim rather than adapt the package to the new one.** The package's source then
stays diffable against upstream, which is the whole point of D11.


## GHC itself: how far the import graph is walked (2026-09-02)

`build/try-ghc.sh` asks `mhs` to compile `Main`, which pulls the whole compiler
in dependency order. Modules that now get through:

```
Main -> HsSyn -> HsDecls -> HsBinds -> HsTypes -> Type -> TypeRep -> Var -> Name
  ... plus CmdLineOpts, Constants, Argv, Util, Unique, OccName, Module, SrcLoc,
      FastString, FiniteMap, Outputable, Pretty, and the 31 boot modules
```

`StringBuffer` is now reimplemented too (`ghc622/shims-ghc/StringBuffer.hs`,
~180 lines, an immutable `Array Int Char` with the lexeme/current index pair,
semantics copied function by function), and **`parser/Lex.lhs` compiles** — the
densest user of GHC-only constructs in the compiler.

### What it took to get here

**Shims** — `common/shims/` (16 modern), `ghc622/shims-h98/` (16 aliases),
`ghc622/shims-ghc/` (16 GHC-internal), of which the load-bearing ones are:

| shim | stands in for | note |
|---|---|---|
| `GlaExts` | GHC's extensions module, 26 import sites | unboxed types are aliases; `I#`/`C#`/`W#`/`F#`/`D#` are **identity pattern synonyms**, so 215 use sites need no source change |
| `FastString` | interned strings | reimplemented; interning is load-bearing (D20) |
| `GhcCompat` | Prelude names base has moved | imported by every module via `HsVersions.h`; one place for base drift |
| `PrelArr`/`ArrBase` | GHC's array types | `ByteArray` is backed by a `String` |
| `Data.Map` | containers | rewritten as a weight-balanced tree |

**Patches** — `phase2/patches/`, all small and mechanical:

| patch | files | what |
|---|---|---|
| 0001 unlit trailing space | 20 | every hunk is a deleted trailing space after `\end{code}` |
| 0002 HsVersions.h | 1 | `SLIT` no longer builds an unboxed string literal (removes **2,021** of them); hide Prelude's `(<>)`; import `GhcCompat` |
| 0003 CmdLineOpts | 1 | `indexArray#` + unboxed tuple -> `(!)` |
| 0004 Unique base-62 | 1 | ByteArray built with ST primops -> a 62-char `String` |
| 0005 unboxed char literals | 3 | `'c'#` -> `'c'`, 138 sites (110 in `Lex.lhs`) |
| 0006 Util | 1 | drop the obsolete `Eval` class from two signatures |
| 0007 named escapes | 2 | `'\NUL'#` -> `'\NUL'`, 10 sites 0005's regex missed |
| 0008 Ctype encoding | 1 | Latin-1 `¡` in a comment -> UTF-8 |
| 0009 drop `_scc_` | 8 | 38 cost-centre annotations, profiling only |

**Generated, not patched** — `build/ghc-hsboot/` (31 `.hs-boot` files from
GHC's `.hi-boot`, via `phase2/hiboot2hsboot.py`), `build/ghc-parsers/` (happy
output), `ghc/includes/config.h` (`phase2/mkconfig.sh`).

### Two findings worth carrying forward

1. **`.hi-boot` is an interface; `.hs-boot` is a module.** GHC's boot files can
   name `Type.PredType` without creating a build edge; `mhs`'s cannot, so the
   converter emits `import {-# SOURCE #-}` between boot modules, and `Type`
   needed a hand-written boot file GHC never had (`phase2/hsboot/`).
2. **Check GHC's build flags before diagnosing a port problem** (D19). Two of
   the four hardest-looking errors were configuration mistakes on our side, not
   incompatibilities.

### Tooling added

- `phase2/hiboot2hsboot.py` — `.hi-boot` -> `.hs-boot`
- `phase2/ppline.py` — show a source line *as `mhs` sees it*, after unlit and
  cpphs. GHC's literate sources renumber twice before the parser sees them, so
  raw line numbers in `mhs`'s errors point at unrelated prose without this.
- `phase2/mkconfig.sh`, `build/try-ghc.sh`
