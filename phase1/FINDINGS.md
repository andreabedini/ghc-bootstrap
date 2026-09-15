# Phase 1 findings — picking the target GHC

Run 2026-09-02, Fedora 44, x86_64.
Goal: score the candidate GHCs mechanically instead of assuming 4.08.2, per the
plan in [`../BOOTSTRAP-ANALYSIS.md`](../BOOTSTRAP-ANALYSIS.md). Candidates are the
four tarballs in the repo root — 4.08.2, 5.00.2, 6.0, 6.10.4. (The plan named
5.04; the repo has 5.00.2, which is the same era.)

Only `ghc/compiler` (`compiler/` in 6.10.4) was scanned. The libraries each GHC
needs are a separate, unmeasured problem — see *What is still unmeasured*.

## Result: 4.08.2 stays the target, and the reasons are not the ones the plan gave

| | 4.08.2 | 5.00.2 | 6.0 | 6.10.4 |
|---|---|---|---|---|
| source modules | **208** | 230 | 272 | 307 |
| code lines | **77,734** | 90,049 | 111,331 | 157,890 |
| modern-extension hits | **3** | 9 | 21 | 239 |
| external imports, distinct | **40** | 50 | 88 | 76 |
| library gap after aliasing | **0 live modules** | 15 | 31 | 28 |
| GHC-internal modules imported | 18 | 17 | 25 | **8** |
| `{-# SOURCE #-}` imports | 52 | **43** | 52 | 57 |
| generated `.hs` shipped as source | **0** | 3 | 3 | 8 |
| extra Haskell tools needed | happy | — | — | hsc2hs |

The plan's hypothesis was that a newer GHC might score far better on language
features and so be worth the extra hops. **It does not.** 6.10.4 is 2× the source
for a strictly larger language surface, a package-level dependency on Cabal and
`filepath`, and eight generated files. The one axis where it genuinely wins —
concentrating its RTS coupling in `GHC.Exts` instead of eighteen `Prel*` modules —
is worth less than 80,000 lines of extra code.

## 0. What had to be fixed before any number meant anything

The scanners were reporting noise. Five corrections, all in
[`../phase0/feature-scan.py`](../phase0/feature-scan.py) and
[`import-inventory.py`](import-inventory.py):

1. **Literate Haskell.** GHC is 207/208 `.lhs` in 4.08.2, LaTeX-style
   (`\begin{code}`, 2,121 blocks; zero bird tracks). The scanner read prose as
   code — and 1990s GHC prose marks inline code as `@thing@`, which produced
   **759 "type-application" hits in a compiler that predates `TypeApplications`
   by 16 years**. Added `code_lines()`, handling both literate styles.
2. **`pattern-guard` matched list comprehensions.** All eight sampled hits in
   4.08.2 were `[ (v,w) | v <- vertices g ]`. Now a `|` with an unclosed `[` to
   its left is skipped, and the match must reach a `=` or `->`.
3. **`view-pattern` matched function types** — `filterBag :: (a -> Bool) -> ...`.
   Now requires a function *and* an argument before the arrow.
4. **`{-# ... #-}` pragmas matched the symbolic-primop regex.** `{-#` and `#-}`
   alone accounted for ~1,300 phantom `-#` uses in 6.10.4. Pragmas are stripped
   before the primop pass.
5. **Generated `.hs` files shipped in the tarball were counted as source** (§4).

The tightening was validated against MicroHs, where the ground truth is known:
in `src/` it drops 95 lines the old regex claimed and keeps 43. Every sampled drop
is a comprehension (`[ s | Import s <- defs ]`); every sampled keep is a real
guard (`| Just op' <- lookup op flipOps = ...`). It now **under**-reports
by roughly the multi-line-guard count (~13 in `src/`), so the figure is a lower
bound where it used to be an upper bound. (This supersedes the "roughly 200
pattern-guard sites" in [`../phase0/FINDINGS.md`](../phase0/FINDINGS.md) §3 — the
old number was mostly comprehensions; the real figure is 64 across `src/` + `lib/`.
The conclusion there is unaffected: Hugs needed the feature either way.)

## 1. The syntax gap is not the discriminator

```
construct        4.08.2   5.00.2      6.0   6.10.4
pattern-guard         3        8       20      205
forall               14       17       25       49
gadt-syntax           0        0        0        1
type-family           0        0        0       27
rec-do                0        1        1        0
cpp                 753      826     1080     1173
unboxed            1029     2586     2333     2544
```

"Modern-extension hits" in the summary table is the sum of every row above except
`forall`, `cpp`, `unboxed`, `tuple-section` and `type-application`, which are
either Haskell 98 or too noisy line-by-line to trust: 3, 9, 21, 239.

**GHC 4.08.2's compiler is essentially Haskell 98.** Its three pattern-guard hits
were checked by hand: two are still multi-line comprehension continuations, so
the real count is **one**:

```haskell
CoreUtils.lhs:  | Just op <- isPrimOpId_maybe v = primOpIsDupable op
```

Every modern-extension column is zero until 6.0, and only 6.10.4 has type families
and GADT syntax at all. `forall` is excluded from the summary count because
its hits are dominated by prose: every one sampled in 4.08.2 is inside a block
comment describing a type (`-- forall f g x. map f (map g x) ==> map (f . g) x`),
not RankN code.

Note what this means for Phase 0's work: the 292 lines of `parser.y` that put
pattern guards into Hugs were needed **for MicroHs**, which uses ~64 of them, not
for GHC. And `mhs` accepts far more than Hugs does, so this axis separates the
candidates barely and separates them in the obvious direction: older is smaller.

## 2. What each compiler needs from outside itself

`import-inventory.py` partitions every import that the tree does not define
itself. The large "gap" numbers from a first run turned out to be mostly
**pre-hierarchical spellings** of modules MicroHs already ships:

```
bucket                      4.08.2   5.00.2      6.0   6.10.4     (modules/sites)
GHC RTS / primop internals   18/75    17/75    25/82     8/60
provided by MicroHs lib       2/5      2/9    21/61   33/402
provided, needs alias       15/116   16/197  11/194    7/68
gap (shim or package)         5/6    15/37   31/151    28/85
```

For 4.08.2 the alias bucket is the whole story — `List`, `IO`, `Char`, `Maybe`,
`IOExts`, `ST`, `Ratio`, `Bits`, `Directory`, `Monad`, `Word`, `Exception`, `Int`,
`System`. MicroHs has all fourteen under their hierarchical names. That is a
`module List(module Data.List) where` shim, not functionality to write.

**For 4.08.2 there is no live library gap at all.** The first run of this tool
reported `Data.Array` missing, because MicroHs's `lib/` has no `Data/Array.hs` —
but it ships that module as **`Mhs.Array`**, complete with `array`, `listArray`,
`accumArray`, `(!)`, `(//)`, `accum`, `ixmap` and a re-export of `Data.Ix`. A
two-line `module Data.Array(module Mhs.Array)` shim compiles under `mhs`, through
`cc`, and runs correctly (`elems (listArray (0,3) "abcd" // [(1,'X')])` →
`"aXcd"`), so this is an alias like the other fourteen. The tool now carries
`MHS_ALIASES` and chains through both maps (`Array` → `Data.Array` → `Mhs.Array`).

That leaves 4.08.2 with five "gap" modules — `IlxGen`, `SocketPrim`, `BSD`,
`NativeInfo`, `IOHandle` — every one a CPP-guarded import for the ILX backend or
another configuration that is off in a normal build. **4.08.2's compiler asks
MicroHs for no functionality it does not already have**; it asks for fifteen
modules under different names.

The `Data.Array.*` family the later GHCs use is a different matter: MicroHs has
the machinery (`Mhs.MutArr`, `Mhs.MutUArr`, `Mhs.UArr`) but not the `MArray` /
`IArray` class interface over it, so those are real shims rather than aliases.
4.08.2 needs none of them.

Two things get much worse further up the chain:

- **6.10.4 depends on packages, not just modules**: `Distribution.*` (Cabal, 6
  modules), `System.FilePath`, `Language.Haskell.TH`, `Trace.Hpc.*`,
  `Data.Sequence`. Each is a real library to port, not an alias.
- **6.0's imports cannot be read without running CPP first.** Its top "gap"
  entries are `DATA_IOREF` (22), `GLAEXTS` (21), `EXCEPTION` (19), `DATA_BITS`,
  `UNSAFE_IO`, `DATA_WORD`, `DATA_INT` — CPP macros from `HsVersions.h` standing
  in for module names. The import graph is not statically visible in the source.
  That is a genuine property of 6.0, not a scanner artifact, and it makes 6.0 the
  worst candidate to reason about mechanically.

## 3. The RTS coupling a shim has to cover

This is the part `BOOTSTRAP-ANALYSIS.md` flagged as "GHC's compiler source reaches
into RTS internals via `base`", now enumerated.

**4.08.2 — 18 modules, 75 import sites:**

```
26 GlaExts     6 Addr        6 PrelAddr    4 IOBase      4 PrelIOBase
 3 PrelPack    3 PackBase    3 PrelST      3 PrelHandle  3 MutableArray
 3 PrelArr     2 STBase      2 PrelForeign 2 ArrBase     2 PrelBase
 1 ByteArray   1 PrelGHC     1 PrelRead
```

**6.10.4 — 8 modules, 60 sites:** `GHC.Exts` (25), `GHC.IOBase` (10), `GHC.Ptr`
(8), `GHC.Base` (7), `GHC.Word` (5), `GHC.Arr` (3), `GHC.Real`, `GHC.ConsoleHandler`.

6.10.4 is tidier here — one modern `GHC.Exts` against 4.08.2's scatter of
`Prel*` modules. But the *quantity* of primop use in hand-written source runs the
other way:

```
                              4.08.2   6.10.4
unboxed types/constructors  523 / 50  187 / 36     (uses / distinct)
symbolic primops (+#, ==#)  249 / 21  223 / 10
lowercase #-names          1454 /259   331 / 95    (primops AND unboxed locals)
unboxed literals                 253        56
```

4.08.2 hand-writes its lexer and string packing with primops (`currentChar#`,
`lookAhead#`, `NUL'#`, `unpackNBytesST`); 6.10.4 pushes that into alex-generated
code — which still has to be compiled (§4), it is just not counted as source.
The distinct-name columns are the ones that size a shim, and they are 50 vs 36
unboxed types and 21 vs 10 symbolic primops: the same order of magnitude.

## 4. The blocker nobody had counted: happy, alex, hsc2hs

GHC's parser is not written in Haskell. Every candidate depends on at least one
Haskell program that must exist before GHC's own source can be compiled — and
each such program is its own bootstrap problem.

| | grammars in tree | generated `.hs` shipped | must run |
|---|---|---|---|
| 4.08.2 | `Parser.y`, `ParseIface.y` | none | **happy** |
| 5.00.2 | 3 | 3 | — |
| 6.0 | 3 | 3 | — |
| 6.10.4 | 8, renamed `*.y.pp.source` / `*.x.source` | 8 (16,378 lines) | **hsc2hs** (`Fingerprint`, `LibFFI`) |

This cuts both ways and the tension is exactly the one this whole project exists
to resolve:

- **4.08.2 ships no generated parser**, so it is honest source throughout — and
  therefore *requires* happy. happy is a small, old, Haskell-98-ish program; making
  `mhs` compile it looks tractable and deserves its own phase, but it is real work
  that was not in the plan.
- **5.00.2, 6.0 and 6.10.4 ship the generated files**, so no happy is needed —
  but those files are generated code in a tarball, which is the same objection
  that disqualified `generated/mhs.c` in Phase 0. Using them weakens the purity
  claim; regenerating them needs happy *and* alex.
- **6.10.4 additionally needs hsc2hs**, which reads C headers and so cannot be
  pre-generated portably. That is a hard dependency no shipped file can remove.

`mhs` still has to compile the shipped generated files either way: 16,378 lines
and 1,121 unboxed uses for 6.10.4, 9,642 lines for 5.00.2, 8,123 for 6.0.

## 5. Mutual recursion is a wash, and it is the one thing already solved

```
              4.08.2   5.00.2      6.0   6.10.4
SOURCE imports    52       43       52       57
naming modules    27       25       28       25
boot files        31       --       --       30
```

The same load-bearing set every time — `TcEnv`, `TcExpr`, `TypeRep`, `TyCon`,
`HsExpr`, `Match`, `DataCon`. This is what makes every candidate impossible for
Hugs and unremarkable for `mhs`, which reads `.hs-boot` (`src/MicroHs/Compile.hs:195`).
No candidate is preferable on this axis, and correcting a figure quoted earlier in
the project: it is ~30 boot modules in both 4.08.2 and 6.10.4, not more in the
newer tree.

## 6. Scoring

| criterion | winner | margin |
|---|---|---|
| size of the port | 4.08.2 | 2.0× smaller than 6.10.4 |
| language features beyond Haskell 98 | 4.08.2 | ~0 vs 232 hits |
| library gap after aliasing | 4.08.2 | 0 live modules vs 28, and no package deps |
| generated code in the trusted base | 4.08.2 | 0 files vs 8 |
| extra bootstrap tools | 5.00.2 / 6.0 | neither needs happy at build time |
| RTS coupling, tidiness | 6.10.4 | 8 modules vs 18 |
| RTS coupling, quantity | 6.10.4 | 741 vs 2,226 uses in source |
| mutual recursion | — | a wash |
| import graph readable without CPP | all but 6.0 | 6.0 hides imports behind macros |
| docks with Guix's existing chain | 4.08.2 | 4.08.2 → 6.0 → 6.6 → 6.10.4 exists |

**Target: 4.08.2**, confirming the plan's guess on evidence rather than on the
Guix argument alone. Its only real disadvantage is needing happy, and happy is a
far smaller problem than the 80,000 extra lines and Cabal dependency that buying
it off with 6.10.4 would cost.

The plan's second criterion — a working unregisterised / via-C backend, so the
output needs only gcc — is satisfied by all four (`-fvia-C` in 4.08.2 through
6.0, `-fvia-C`/unregisterised in 6.10.4). It does not discriminate.

## What is still unmeasured

The honest limits of this pass:

1. **Nothing here was checked against `mhs`.** These counts say what GHC *uses*,
   not what MicroHs *rejects*. The complementary tool — run `mhs` over the tree
   and collect its actual errors — does not exist yet, and it is the one that
   turns this from triage into a verdict.
2. **Only `ghc/compiler` was scanned.** GHC 4.08.2 also needs its own `ghc/lib`
   and hslibs to build, and whether *those* can come up under `mhs` is untouched.
3. **The C side is untouched**: the RTS, the `.hc` route, and whether 1999-era
   register-mangled C survives GCC 16 (Phase 0 needed `-fpermissive` just for
   Hugs; the same class of problem is certain here).
4. **CPP.** All four need it heavily (753–1,173 directives). MicroHs ships a cpphs
   bootstrap path (`make bootstrapcpphs`), which is the right answer, but it has
   not been exercised in this chain.
5. **The 32-bit `Int` problem from Phase 0 §6 does not apply here** — that was
   MicroHs running *under Hugs*. From `bin/hmhs` onward `Int` is 64-bit, so
   nothing in this phase inherits it.

## Reproducing

```sh
tar xjf ghc-4.08.2-src.tar.bz2
phase0/feature-scan.py      ghc-4.08.2/ghc/compiler   # syntax gap
phase1/import-inventory.py  ghc-4.08.2/ghc/compiler   # imports, RTS, generated code
```

`import-inventory.py` cross-references `../MicroHs/lib` by default; point it
elsewhere with `--mhs-lib=PATH`. Both tools are heuristic and line-based by
design: they size a port, they do not parse Haskell.
