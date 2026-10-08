# gen622: GHC 6.2.2's generated sources, regenerated in-chain

Regenerated with the in-chain tools only (happy-mhs2, cpphs, an mhs-built
genprimopcode); no installed GHC or happy touched. Everything under this
directory is reproduced by `sh regen.sh`; `VALIDATE60=1 sh regen.sh` re-runs the
6.0 check. Outputs use the same relative paths as `ghc/compiler`.

## Recipe

| output | input (pristine `build/rebase622/ghc-6.2.2/ghc/compiler`) | tool and flags |
|---|---|---|
| `prelude/primops.txt` | `prelude/primops.txt.pp` | `cpphs --noline --strip -Igen622/includes -I<ghc/includes>` |
| `prelude/primop-*.hs-incl` (10) | `prelude/primops.txt` | `genprimopcode --<flag> < primops.txt`, the ten flags of `ghc/compiler/Makefile` |
| `parser/Parser.hs` | `parser/Parser.y` | `happy-mhs2 <y> -o <hs>`, no flags |
| `parser/ParserCore.hs` | `parser/ParserCore.y` | same |
| `main/ParsePkgConf.hs` | `main/ParsePkgConf.y` | same |

How this was established:

- **happy.** GHC's build runs `$(HAPPY) $(HAPPY_OPTS) $<` (`mk/suffix.mk`), with
  `GHC_HAPPY_OPTS = -agc` (`mk/config.mk.in:924`) selected when the host compiler
  is GHC, plus `+RTS -K2m -RTS`. `-agc` is the GHC-specific template (arrays,
  `Addr#` tables, `happyTcHack`), so it is dropped: happy-mhs2 with no flags uses
  the portable `HappyTemplate` in `build/happy-mhs/datadir` (`HAPPY_DATADIR`).
  happy-mhs2 is the fixpoint-verified binary (phase2/FINDINGS.md milestone).
  The `.y` files are **not** cpp'd before happy: each has exactly one cpp line
  (`#include "HsVersions.h"`, `../HsVersions.h` in ParserCore.y), which passes
  through into the `.hs` and is resolved when the `.hs` is compiled with CPP.
  This is exactly how the 6.0 files in `build/ghc-6.0-run2` were made (they
  still contain the `#include`).
  **Post-processing (added 2026-09-15).** happy 1.19.5's template writes
  three things a 2004 GHC rejects, invisible while mhs was the only consumer:
  `{-# OPTIONS_GHC -w #-}` (6.2.2's matchOptions reads `_GHC` as a flag),
  `import Control.Applicative(Applicative(..))` and `import Control.Monad (ap)`
  (no such module in 6.2.2's base; unused under `%monad`), and `(P)
  HappyAbsSyn` in the action_*/happyReduce_* signature block (with
  ParserCore's `type P a = String -> Int -> ParseResult a`, 6.2.2 leaves the
  parenthesised synonym head unexpanded and cannot unify it with a function
  type). `ghc622/tools/fix-generated-parsers.sh` rewrites all three; `regen.sh`
  and `phase4/regen-generated.sh` call it after each happy run. Details and
  the experiments in `build/ghc622-stage2/LOG.md` (2026-09-15).
- **cpp for primops.** The Makefile's `% : %.pp` rule is
  `$(CPP) -undef -traditional -P -I$(GHC_INCLUDE_DIR) -x c ... | grep -v '^#pragma GCC'`.
  gcc's cpp does *not* reproduce the 6.0 `primops.txt` (tabs collapsed, comment
  bodies dropped); `cpphs --noline --strip` reproduces it byte for byte, so the
  6.0 run used cpphs, and so does this one. `--strip-eol` also matches;
  `--noline` without `--strip` does not (comment bodies differ at line 66).
- **config.h.** `primops.txt.pp` includes `MachDeps.h`, which includes
  `config.h` (configure output, absent from the pristine tree).
  `includes/config.h` is 6.2.2's x86_64 configure output, copied from
  `build/ghc-6.2.2-run1/ghc/includes/config.h` (identical to the copy in
  `build/rts622`). All that primops.txt.pp consumes from it is
  `SIZEOF_VOID_P 8` -> `WORD_SIZE_IN_BITS 64`, and `mingw32_TARGET_OS`/`ILX`
  undefined. Because cpphs `--strip` keeps the line structure of included
  files as blank/space lines, the 6.2.2 `primops.txt` is longer (2953 lines)
  than 6.0's (2383) only because 6.2.2's config.h is longer; genprimopcode
  ignores blank lines.
- **genprimopcode.** `build/genprimopcode/genprimopcode` (built for 6.0)
  reproduces all ten 6.0 `.hs-incl` byte for byte, but its source predates
  6.2.2's: 6.2.2's `utils/genprimopcode/Main.hs` additionally emits
  `maxPrimOpTag = N :: Int` at the top of `primop-tag.hs-incl`. So
  `genprimopcode/genprimopcode` here is compiled by mhs from 6.2.2's own
  `Main.hs` (pristine copy from `build/ghc-6.2.2/ghc/utils/genprimopcode/`,
  same bytes as in `build/rts622`), with one edit (below), using
  `ghc622/shims-h98` for `Monad/Char/List/Maybe/System` and `genprimopcode/Parsec.hs`
  (the slice-of-Parsec shim from `ghc622/shims`, identical to
  6.0-run2's) for the `import Parsec` branch that cpphs selects because
  `__GLASGOW_HASKELL__` is undefined. Cross-check: this binary on 6.0's
  `primops.txt` reproduces 9/10 of 6.0's files byte for byte; the tenth,
  `primop-tag.hs-incl`, differs only by the added `maxPrimOpTag = 318 :: Int`
  line. Nothing in the 6.2.2 compiler references `maxPrimOpTag` (rg over
  `ghc/compiler`: no hits), so the line is inert but faithful to 6.2.2's tool.

## 6.0 validation (step 2)

Inputs: pristine `build/rebase622/ghc-6.0/ghc/compiler` (byte-identical to the
`.y`/`.pp` in `build/ghc-6.0-run2`; neither `6.0-current.patch` nor
`6.0-run2.patch` touches a `.y`, `primops.txt.pp`, `primops.txt` or `.hs-incl`).
Reference: `build/ghc-6.0-run2/ghc/compiler`. Result of `VALIDATE60=1 sh regen.sh`
(`tmp/regen-validate60.log`): **all 14 files IDENTICAL** —
`primops.txt` (70383 B), the ten `primop-*.hs-incl`, `ParsePkgConf.hs` (16741 B),
`ParserCore.hs` (57830 B), `Parser.hs` (513516 B). happy reported 29 s/r
conflicts for 6.0's Parser.y, matching the grammar's header ("Conflicts: 29
shift/reduce"), and 1 unused terminal for ParserCore.y.

## 6.2.2 results (steps 3-4)

happy-mhs2 accepted all three 6.2.2 grammars unchanged; no grammar patch needed.
The full regen was run twice and the 14 outputs are identical across runs.

| file | bytes | lines | happy report |
|---|---|---|---|
| `parser/Parser.hs` | 537264 | 16856 | 32 shift/reduce, 5 unused rules |
| `parser/ParserCore.hs` | 59387 | 2336 | (clean) |
| `main/ParsePkgConf.hs` | 16689 | 721 | (clean) |
| `prelude/primops.txt` | 80118 | 2953 | 319 primops (`maxPrimOpTag = 319`) |
| `prelude/primop-data-decl.hs-incl` | 6695 | | |
| `prelude/primop-tag.hs-incl` | 16809 | | first line `maxPrimOpTag = 319 :: Int` |
| `prelude/primop-list.hs-incl` | 6687 | | |
| `prelude/primop-has-side-effects.hs-incl` | 3087 | | |
| `prelude/primop-out-of-line.hs-incl` | 2178 | | |
| `prelude/primop-commutable.hs-incl` | 752 | | |
| `prelude/primop-needs-wrapper.hs-incl` | 1383 | | |
| `prelude/primop-can-fail.hs-incl` | 491 | | |
| `prelude/primop-strictness.hs-incl` | 182 | | |
| `prelude/primop-primop-info.hs-incl` | 41799 | | |

**Conflicts.** 6.2.2's Parser.y has no `%expect`; its header still says
"Conflicts: 29 shift/reduce" but its own itemised list adds "4 for ambiguity in
`if x then y else z -< e`" (arrow notation, new in 6.2) while the "1 for
`if x then y else z with ?x=3`" entry is stale (`with` bindings were removed).
The info files (`tmp/info60/Parser.info`, `tmp/info622/Parser.info`) confirm
exactly that: the eight conflicting states are the same in both versions and
only the `if`-expression state changed, 12 -> 15 s/r (`infixexp . '-<' exp` and
`'-<<'` added, `infixexp . 'with' dbinding` gone): 29 - 1 + 4 = 32. The other
seven states are unchanged (`e :: a \`b\` c` 4+4, RULES activation 1+1, `let ?x` 1,
fdecl/fdeclDEPRECATED 3+3). So 32 is what 6.2.2's grammar yields under any
happy, not an artefact of happy 1.19.5.

**Unused rules (5).** `ccallid -> VARID`, `ccallid -> CONID`, `aexps0 -> aexps`,
`dbinding -> '{' dbinds '}'`, `dbinding -> vocurly dbinds close`: nonterminals
left defined after 6.2.2 deleted the `_ccall_`/`_casm_` productions and
`infixexp 'with' dbinding`. Harmless (dead code in the generated parser).

**GHC-only constructs.** `rg` over the three `.hs` for `GHC.Exts`, `happyTcHack`,
`Happy_GHC_Exts`, `MagicHash`, `unsafeCoerce#`, `(#`: none. The only `#`
characters are the `{-# OPTIONS_GHC -w #-}`/`{-# NOINLINE #-}` pragmas and the
one `#include` line per file, as in the 6.0 output.

**Imports to expect.** `Parser.hs` and `ParsePkgConf.hs` import `Lexer` (the
alex-based lexer being ported separately) and thread the `P` monad;
`ParserCore.hs` imports `LexCore`, `ParserCoreUtils`. Each generated parser
also imports `Control.Applicative(Applicative(..))` and `Control.Monad (ap)`
(happy 1.19.5's template), as the 6.0 ones do. `ParserCore.hs` keeps
`#include "../HsVersions.h"`, so it needs `-I<ghc/compiler/parser>` or
`-I<ghc/compiler>` semantics identical to how 6.0-run2 compiled it.

## Patches

`patches/genprimopcode-Main.hs.patch` — one line in
`ghc/utils/genprimopcode/Main.hs`: `filter (not.dodgy)` -> `filter (not . dodgy)`
(`-- mhs: "not.dodgy" lexes as record-dot selection`; mhs reports
`Cannot satisfy constraint: HasField "dodgy"`). It is for compiling the tool
with mhs, not for the generated output, which is unaffected. No `.y` or
`primops.txt.pp` patch was needed.

## Layout

```
regen.sh                 reproduces everything below from the pristine tree
includes/config.h        6.2.2 x86_64 configure output (for MachDeps.h)
genprimopcode/           Main.hs (pristine + patch), Parsec.hs shim, mhs-built binary
patches/                 genprimopcode-Main.hs.patch
parser/ main/ prelude/   the 14 deliverables
tmp/                     TMPDIR for the mhs-built tools; happy .info files (info60/, info622/),
                         6.0 validation outputs (val60/), logs (regen-*.log)
```

Timings on this machine: genprimopcode compile ~50 s, Parser.y ~55 s, the rest
seconds; a full `regen.sh` is under 2 minutes.
