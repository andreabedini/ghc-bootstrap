# Decision log — bootstrapping GHC

Newest last. Each entry: what was decided, why, and what would overturn it.
Detail lives in the phase findings; this file is the index of *choices*.

---

### D1 — The seed is C compiler + Hugs source, not MicroHs's shipped `.comb`
*Phase 0, 2026-09-02.* Verified end to end: Hugs runs the MicroHs compiler,
which emits C for itself; the result reaches a byte-identical fixpoint and
matches the compiler built from MicroHs's shipped seed (diverse double
compilation). Details: [`phase0/FINDINGS.md`](phase0/FINDINGS.md).

**Overturned by:** nothing so far. This is the one fully-verified link.

---

### D2 — Target GHC **4.08.2**, on measurement rather than on the Guix argument
*Phase 1, 2026-09-02.* All four candidate tarballs were scanned. 4.08.2 is half
the source of 6.10.4 (77,734 vs 157,890 lines), has 3 modern-extension hits vs
239, needs no external packages, and ships no generated Haskell. 6.10.4's only
advantage — RTS coupling concentrated in `GHC.Exts` rather than 18 `Prel*`
modules — does not pay for 80,000 extra lines and a Cabal dependency.
Details: [`phase1/FINDINGS.md`](phase1/FINDINGS.md).

**Overturned by:** discovering that `mhs` rejects something structural in
4.08.2 that a later GHC avoids. Nothing found yet; the `mhs`-side check has not
been run.

---

### D3 — Shims live in `phase1/shims/`, as the start of `ghc-on-mhs`
Rather than throwaway scaffolding per experiment. They are written against
MicroHs's real machinery (`Mhs.Array`, `Mhs.MutArr`) rather than simulated, so
they carry over to Phase 2 unchanged.

---

### D4 — happy is a required sub-bootstrap, not an optional detour
4.08.2 ships `Parser.y` and `ParseIface.y` with **no** generated `.hs`, so its
parser cannot be built without happy — and happy is a Haskell program. The
alternative (take a later GHC's shipped generated parser) trades this for a
larger generated artifact inside GHC itself, which is strictly worse for the
purity argument. Paying the cost at happy's scale (a 148-line grammar) is the
cheap end of the trade.

---

### D5 — No shipped happy parser can be used; the grammar must be regenerated
*2026-09-02.* Checked every happy tarball on Hackage from 1.15 to 1.19.12:

| version | ships `Parser.ly` | ships generated `Parser.hs` | portable? |
|---|---|---|---|
| 1.15 | no | no | — |
| 1.16 | yes | yes | **no** — unguarded `HappyA# "…"#`, `Addr#`, `narrow16Int#` |
| 1.17 – 1.19.5 | yes | no | — |
| 1.19.12 | no | yes | **no** — `-XMagicHash`, 53 × `unsafeCoerce#`/`HappyA#` |

`mhs` rejects both generated parsers on the same construct: an unboxed `Addr#`
string literal (`HappyA# "\x00…"#`), which is lexical and cannot be shimmed.
(`mhs` *does* accept MagicHash identifiers and has `Unsafe.Coerce`, so
`unsafeCoerce#` alone would have been shimmable.) This is clarifying rather than
blocking: the "trust the shipped blob" shortcut does not merely offend purity
here, it does not work.

---

### D6 — Bootstrap happy **1.19.5**
Its tarball is genuine source: both `.ly` grammars, no generated `.hs`, and the
portable `templates/GenericTemplate.hs`. 1.19.12 would require fetching the
grammars from the repository; 1.16 and earlier ship a generated parser we cannot
use anyway.

---

### D7 — Use the machine's GHC 9.14.1 as a **one-time generator**, then discharge it
This is the only place a pre-existing Haskell toolchain enters, and it is
deliberate. The chain is:

1. `cabal`/GHC builds `happy-ghc` — **outside the trusted base**.
2. `happy-ghc` turns `Parser.ly` into a *portable* `Parser.hs` (generic
   template, no `--ghc`).
3. `mhs` compiles that plus `phase1/shims/` → `happy-mhs`. **This** is the
   artifact the chain uses.
4. `happy-mhs` regenerates `Parser.hs` from `Parser.ly` and the result must be
   byte-identical to step 2's output.

After step 4, `happy-ghc` is out of the trusted base: the file it produced is
reproducible from source by a compiler derived from the Hugs seed.

**Known limitation, stated plainly:** this is a *fixpoint*, weaker than D1's
diverse double compilation. Two independent producers agreeing (Hugs-derived and
seed-derived) detects a Thompson attack; a self-fixpoint proves only
self-consistency. Closing that gap needs a second, independent producer of
happy's parser — feasible at 148 lines of grammar, but not done here.

---

### D8 — Artifacts live in `build/` inside the project, not in `$TMPDIR`
Sources, extractions and intermediate compilers are reproducible but slow to
rebuild, and a temp directory loses them between sessions.

---

### D9 — The generator must be happy **1.19.x**, not the current happy
*2026-09-02.* `cabal install happy` produces **happy 2.2**, which refuses to
emit portable code:

```
Warning: With happy 2.0, the --ghc flag has become non-optional.
```

happy 2.x always generates `MagicHash`/`Addr#` output — precisely what `mhs`
cannot lex (D5). Installed `happy-1.19.12` alongside it instead
(`build/tools119/happy-1.19`); run with no flags it emits the generic
`Data.Array`-based template. Verified on happy 1.19.5's own grammars: the
generated `Parser.hs` (1,344 lines) and `AttrGrammarParser.hs` (962 lines)
contain zero occurrences of `MagicHash`, `HappyA#`, `unsafeCoerce#`, `GHC.Exts`
or `Addr#`.

**Overturned by:** happy 2.x regaining a portable backend, or `mhs` learning
unboxed string literals. Neither is likely to matter — 1.19.x is the right era
for GHC 4.08.2's grammar anyway.

---

### D10 — happy 1.19 handles GHC 4.08.2's grammar; both parsers generated portably
*2026-09-02.* The compatibility question that D4/D6 depended on is settled
empirically. `happy-1.19.12` processes GHC 4.08.2's 1999-era grammars:

```
Parser.y      unused terminals: 3   shift/reduce conflicts: 21   -> 11,243 lines
ParseIface.y  unused rules: 2       unused terminals: 17         ->  7,737 lines
```

21 shift/reduce conflicts is normal for GHC's grammar, not a failure. Both
outputs contain zero `MagicHash` / `HappyA#` / `unsafeCoerce#` / `GHC.Exts` /
`Addr#`, so they are `mhs`-compilable in principle. They live in
`build/ghc-parsers/`.

**These are currently outside the trusted base**, having been produced by the
GHC-built happy. They are discharged the same way as D7: once `happy-mhs`
exists, it must regenerate both byte-identically.

---

### D11 — The GHC tarball stays pristine; everything else is a side directory or a patch
Generated parsers go in `build/ghc-parsers/` and reach the compiler through
`mhs -i`, not by being copied into `ghc-4.08.2/ghc/compiler/parser/`. Shims go in
`phase1/shims/`. Source changes, when they become unavoidable, go in a numbered
patch series against the unmodified tarball, as `phase0/patches/` already does
for Hugs and MicroHs.

This is what `BOOTSTRAP-ANALYSIS.md` means by keeping the result auditable
rather than "a fork that happens to compile": at any point it must be possible
to diff what we changed against what upstream shipped.

---

### D12 — Restore the pre-`MonadFail` `Either` instance rather than patch happy
*2026-09-02.* First genuine language-level incompatibility found. `mhs` rejected
the generated parser with:

```
Cannot satisfy constraint: MonadFail (ReaderT ([Char], Int) (Either [Char]))
```

Source: happy's own grammar defines `happyError = fail "Parse error\n"` in
`P a = ReaderT (String,Int) (Either String) a`. Pre-`MonadFail` mtl put `fail`
in `Monad` and gave `Either e` the instance `fail = Left . strMsg`; base later
split `MonadFail` out and dropped it, and MicroHs follows modern base (its only
`MonadFail` instance is `[]`).

Fixed in `phase1/shims/Control/Monad/Reader.hs` with the two instances mtl used
to supply:

```haskell
instance MonadFail (Either String)       where fail = Left
instance MonadFail m => MonadFail (ReaderT r m) where fail msg = ReaderT (\_ -> fail msg)
```

**Why the shim and not a patch to happy:** the shim is standing in for a
*specific historical version of mtl*, and this is exactly what that version did.
Patching happy would make its source disagree with the upstream tarball for a
reason that has nothing to do with happy. It also keeps the failure a `Left`,
which is what happy's callers match on — an `error`-based `MonadFail` would have
compiled and then misbehaved at runtime on any parse error.

**General principle this sets:** where MicroHs's `base` differs from the `base`
a package expects, prefer a shim that reproduces the *old* behaviour over a
patch that adapts the package to the new one. Phase 2's `ghc-on-mhs` will need
the same rule repeatedly.

---

### D13 — Drop happy's GLR backend, by shadowing rather than patching
*2026-09-02.* `ProduceGLRCode.lhs` does not compile under `mhs`:

```
Cannot satisfy constraint: [] ~ ([Char] ->)
```

It is `header_parts = fmap (span p . lines) header` with `header :: Maybe String`;
`mhs` appears to resolve the `Functor` at `((->) a)` rather than `Maybe`, and the
list/function mismatch surfaces at the use site `maybe [] fst header_parts`.
MicroHs has all three function instances (`Functor`/`Applicative`/`Monad` for
`((->) a)`), so the instance exists to be picked wrongly.

**GHC needs none of it.** `Parser.y` and `ParseIface.y` are ordinary LALR
grammars and `--glr` is never passed. So `phase2/happy-noglr/ProduceGLRCode.hs`
provides the same module interface — the three option types, the same entry
point — with `produceGLRParser` raising an `IOError`, and sits *earlier* on the
`-i` path so it shadows the real module. happy's source is untouched (D11), and
a happy built this way is correct for every grammar that does not pass `--glr`.

**Open question, deliberately parked:** whether this is an `mhs` inference bug
worth a minimal repro and an upstream report. It is not on the path to a
bootstrapped GHC, but it is the first thing found that looks like a real `mhs`
limitation rather than a missing library.

---

### D14 — Verify happy by generation, not by equality with `happy-ghc`
*2026-09-02.* The obvious D7 test — "does `happy-mhs` reproduce what `happy-ghc`
produced?" — is the **wrong** test here, and running it showed why. The two
disagree by 31 lines on GHC's `Parser.y`, and the diff is entirely happy's
`happyExpList` / `happyExpListPerState` feature (expected-token error reporting),
which 1.19.12 emits and 1.19.5 does not. The grammar tables are identical; only
`happyFail` gains an argument.

That is a *version* difference between the generator and the source being
bootstrapped, not a discrepancy. So the discharge is generational, exactly as
Phase 0 did for MicroHs:

```
gen1  parsers from happy-ghc      -> happy-mhs1
gen2  happy-mhs1 regenerates them -> happy-mhs2
gen3  happy-mhs2 regenerates them -> compare with gen2
```

`gen2 == gen3` means happy's parsers are reproducible from its own `.ly`
grammars by a compiler descended from the Hugs seed, and `happy-ghc` leaves the
trusted base. GHC's parsers are then regenerated with `happy-mhs2`, so
`build/ghc-parsers/` becomes an in-chain artifact too.

Also corrected here: the `Paths_happy` shim claimed version 1.19.12 while the
source is 1.19.5, and happy stamps that into every file it generates. Fixed
before the fixpoint ran, so the comparison is on honest output.

---

### D15 — The three feared blockers all dissolved; `mhs` is more capable than assumed
*2026-09-02.* Before writing any RTS shim, each suspected structural blocker was
probed directly. All three are non-issues:

| feared blocker | probe | result |
|---|---|---|
| unboxed literals `0#` | `print (0# + 1#)` compiled, linked, ran | prints `1` — `mhs` lexes them fine |
| boxing constructors `I#`, `C#` (215 uses, 35 modules) | `pattern I# x = x` then `case n of I# m -> I# (m+m)` | `double 21` = `42` — **`mhs` has pattern synonyms** |
| mutually recursive modules (31 `.hi-boot`) | converted to `.hs-boot`, put on the `-i` path | accepted; the cycle is broken |

The pattern-synonym result is the important one. It means GHC's `case n of I# n#`
and `I# (a +# b)` compile **unmodified** against a shim where `type Int# = Int`
and `pattern I# x = x`. 215 use sites that looked like a mandatory patch series
turned out to need no source change at all.

What actually stopped `mhs` in happy was narrower than "unboxed things": an
unboxed *string* literal, `HappyA# "\x00..."#`, which is lexical. GHC 4.08.2's
compiler has none.

**Method note worth keeping:** every one of these was settled by a three-line
probe in under a minute. Phase 1's static counts said what GHC *uses*; only the
probes say what `mhs` *refuses*, and the difference between the two was the
difference between "large patch series" and "no patch at all".

---

### D16 — Patch GHC for `mhs`'s stricter unlit, rather than change the verified seed
*2026-09-02.* `mhs`'s literate-Haskell reader matches the delimiters exactly
(`Compile.hs:581,588`: `un n _ ("\\begin{code}":ls)`), so a line reading
`\end{code}` **with a trailing space** stays in the code block and reaches the
parser as a stray `\`. 20 of GHC 4.08.2's `.lhs` files have such a line.

GHC's own `unlit` tolerates trailing whitespace, so `mhs` is the stricter of the
two and arguably the one that is wrong. Fixing `mhs` would be a two-line change
— but `mhs` is the *verified seed*, and changing it invalidates Phase 0's
fixpoint and DDC results until `phase0/bootstrap-seed.sh` is re-run.

So the fix goes on the GHC side, as
`phase2/patches/0001-ghc-unlit-trailing-space.patch` — 20 files, 224 lines, and
every hunk is a deleted trailing space. It is the most auditable kind of patch
there is, and it leaves the project's one fully-verified artifact untouched.

**Follow-up worth doing, not on the critical path:** send the unlit fix upstream
to MicroHs, and drop this patch when it lands.

---

### D17 — Preprocess GHC with `-D__GLASGOW_HASKELL__=408`
With the macro undefined, `cpphs` evaluates `#if __GLASGOW_HASKELL__ < 301` as
true and selects GHC's *oldest* compatibility branches, which import modules
(`PackBase`, `ByteArray`) that predate even 4.08. Defining it to 408 selects the
branches GHC 4.08.2's authors actually compiled, so the shim surface is the one
they intended (`PrelPack`, `PrelAddr`, …) rather than a 1996 archaeology layer.

---

### D18 — Upstream MicroHs chose the other fix for the Hugs problem
*Noted 2026-09-02, from a survey of `augustss/MicroHS`'s 46 remote branches.*

There is an unmerged `origin/hugs` branch (last commit 2025-03-19, ~18 months
behind master) that solves Phase 0's blocker the *other* way: instead of adding
pattern guards to Hugs, it hand-rewrites MicroHs's own pattern guards into
`case` expressions (43 in `src/` on master, 1 on that branch).

Our choice — `phase0/patches/0002`, 292 lines of Hugs `parser.y` — is the better
artifact for a bootstrap argument: it fixes the *seed compiler* once, for every
program it will ever compile, rather than contorting the program being compiled,
and it does not need redoing each time MicroHs grows a new pattern guard. Master
has since re-accumulated 43 of them, which is precisely why that branch went
stale.

Worth recording next to D1 so a reader does not wonder why we patched Hugs at
all when upstream did something else.

Also checked: no upstream branch supplies what `phase1/shims/` provides.
`origin/oleg+more` has a weight-balanced `Data.Map`, but with a
comparator-passing API (`lookupBy :: (k -> k -> Ordering) -> ...`), no `Ord`
constraints, no `Data.Set`, and no mtl — it would not drop in where GHC or happy
expect `containers`.

---

### D19 — GHC's own build flags are the specification for how to preprocess it
*2026-09-02.* Several errors that looked like language incompatibilities were
really "we are preprocessing GHC differently from how GHC preprocesses itself".
The fix each time was to pass what `ghc/compiler/Makefile` and `mk/version.mk`
pass:

| flag | why | what it fixed |
|---|---|---|
| `-D__GLASGOW_HASKELL__=408` | selects GHC 4.08's own code paths | stopped CPP picking 1996-era modules (`PackBase`, `ByteArray`) |
| `-D__HASKELL1__=5` | the source is Haskell 98 | `FMAP` was expanding to `map` instead of `fmap`, giving `[] ~ Maybe`; also fixes `ISALPHANUM`, `IOERROR`, `PSEQ`, `SAPPLY` |
| `-DHscIfaceFileVersion=5` | `mk/version.mk:57` | undefined value `HscIfaceFileVersion` |
| `-DOMIT_NATIVE_CODEGEN` | `Makefile:46`, set when `GhcWithNativeCodeGen=NO` | drops `nativeGen/` entirely — the right choice for the unregisterised via-C route, and it removes a lot of primop-heavy code |

**The lesson, worth applying to the rest of Phase 2:** before shimming or
patching anything, check whether GHC's own build system already says how that
module is meant to be preprocessed. Two of the four above were being
"diagnosed" as porting problems when they were configuration mistakes.

---

### D20 — The three raw-memory modules get reimplemented, not emulated
`PrimPacked`, `FastString` and `StringBuffer` (~1,500 lines) exist to poke bytes
through `Addr#`/`ByteArray#`/`indexCharOffAddr#` and GHC 4's C-label syntax
(``prog_argv''). Emulating those primops on MicroHs would be more work and less
trustworthy than reimplementing the ~60 functions the three modules export.

`FastString` is done (`phase1/shims-ghc/FastString.hs`): a String plus an
interned `Int`, because `Unique.getUnique` *is* `uniqueOfFS`, so interning is
load-bearing rather than an optimisation — two equal strings must get the same
`Int` or name resolution breaks. That in turn is why `Data.Map` was rewritten
from a sorted list into a weight-balanced tree: one lookup per identifier in the
source makes O(n) per operation O(n^2) over a compilation.

`StringBuffer` is now done too (~180 lines, an immutable `Array Int Char`
carrying the lexeme-start/current index pair, semantics copied function by
function including the NUL sentinel and the "EOB, return immediately" cases the
lexer depends on).

**`PrimPacked` turned out not to be needed at all.** Its only three consumers
were `FastString`, `StringBuffer` and `DirUtils`; the first two are
reimplemented, and `DirUtils` exists solely to work around a 1999 bug in
`Directory.getDirectoryContents` using GHC 4's `_ccall_` syntax, so it is
shadowed by a two-line forward to the standard function. Emulating GHC's
`Addr#`/`ByteArray#` primops was never necessary — replacing the three modules
that used them removed the requirement entirely.

---

### D21 — The long tail is GHC-only *syntax*, and it is short
*2026-09-02.* Past the RTS shims, what remained was a handful of constructs that
only GHC ever accepted. Each is removed by a mechanical patch, and the whole
tail is smaller than any one of the shims:

| construct | sites | patch | why it is safe |
|---|---|---|---|
| `SLIT(x)` -> `"..."#` | 2,021 | 0002 | `mkFastString x` is the same value |
| `'c'#` unboxed chars | 138 | 0005 | `Char# = Char` in the shim |
| `'\NUL'#` named escapes | 10 | 0007 | 0005's regex missed multi-char escapes |
| `_scc_ "label" e` | 38 | 0009 | cost-centre annotation; profiling only, semantically the identity |
| ``` ``prog_argv'' ``` C labels | 2 | shimmed `Argv` | the module's whole job is `getArgs` |
| `indexArray#` + `(# v #)` | 1 | 0003 | `(!)` is the portable equivalent |
| ST byte-array table | 1 | 0004 | a 62-character constant string |
| `Eval` class | 2 | 0006 | the class no longer exists; `seq` is unconstrained |
| Latin-1 source byte | 1 | 0008 | `Ctype.lhs` had a `¡` in a comment; converting the file to UTF-8 keeps the code point |

Two details worth keeping:

- **`_scc_` needs a space in the pattern, and must not cross a newline.**
  Two separate traps, and the second one bit.
  `Lex.lhs:278` has `( "_scc_", ITscc )` — the lexer's own keyword table — so
  the pattern requires a space before the string. But the first version also
  ended in `\s*`, which *consumed the newline*, and in `Main.lhs`:

  ```haskell
  main = stderr `seq`   -- Bug fix.  Sigh
   --  _scc_ "main"
   doIt classifyOpts        <- folded into the comment above
  ```

  the annotation sat inside a comment, so deleting it and the following newline
  joined the next line onto that comment and **silently deleted `main`'s body**.
  It surfaced as a syntax error in `Main.lhs`, and for a while looked like GHC
  4.08.2 had shipped a broken `main`. The pattern now matches `[ \t]*` only.

  **The general lesson for a mechanical patch series:** a regex that deletes
  text must never be allowed to span a line, because the failure mode is not a
  patch that does not apply — it is a patch that applies and quietly changes the
  meaning of the program. Every patch in `phase2/patches/` is worth reading as a
  diff for exactly this reason.
- **`Char(..)` no longer names a constructor.** `Ctype.lhs` imports
  `PrelBase(Char#, Char(..))` for `C#`. In the shim `C#` is a pattern synonym,
  which an import list has to name explicitly, so the import gains
  `pattern C#`.

With those, **`parser/Lex.lhs` compiles** — the lexer was the densest user of
GHC-only constructs in the compiler, and it is the module the whole front end
depends on.

---

### D22 — A duplicate item in an import list, and a lesson about error messages
*2026-09-02. This entry originally recorded an elaborate and **wrong**
diagnosis; it is rewritten here rather than deleted, because the way it went
wrong is the useful part.*

`coreSyn/Subst.lhs` failed with:

```
not exported: WorkerInfo
```

The actual cause is one line of GHC's source:

```haskell
import IdInfo ( IdInfo, isFragileOccInfo,
                specInfo, setSpecInfo,
                WorkerInfo(..), workerExists, workerInfo, setWorkerInfo, WorkerInfo )
                                                                         ^^^^^^^^^^
```

`WorkerInfo` is named **twice** — once with `(..)` and once bare. GHC tolerated
it; `mhs` rejects the duplicate and reports it as "not exported", which points
at the wrong problem entirely. Patch `0011` deletes the second occurrence.

**What the misleading message cost.** "not exported" made it look like a module
*resolution* problem, and `Var` SOURCE-imports `IdInfo`, so there was a
plausible story ready to hand: the boot file shadows the real module. Hours went
into that story. Every experiment along the way was sound and every conclusion
drawn from it was true —

| tested | result |
|---|---|
| is the boot file read at all? | yes — a syntax error in it was reported |
| can a boot export data constructors? | yes — 4-module repro compiles |
| does `IdInfo` really export it? | yes — direct probe compiles |
| does import order matter? | no |
| is GHC's boot direction wrong? | no — reversing it makes a worse cycle |

— and none of it was relevant, because the premise was wrong. An `-l` trace even
"confirmed" the theory by showing the boot loading before `Subst` and the real
module after; that is simply what the trace looks like either way.

**The lesson, which is the reason to keep this entry:** when an error message
names a thing that demonstrably *is* exported, suspect the message before
building a theory around it. The cheap move — read the offending line
character by character — was available from the first minute and would have cost
nothing. Reach for it before reaching for a mechanism.

**Also invalidated by this:** the enriched `IdInfo.hs-boot` and `CoreSyn.hs-boot`
written to support the wrong theory turned out to be unnecessary and were
removed; only `phase2/hsboot/Type.hs-boot` is genuinely needed (D22a below).
The topological build order (`phase2/build-order.py`,
`phase2/build-order.txt`, `build/build-ghc.sh`) was also written for this
theory. It is **kept** — it mirrors what GHC's own `mkdependHS` does, it is
useful for building incrementally and resuming, and it costs nothing — but it
was not the fix.

---

### D22a — `Type` needs a boot file GHC never had
`.hi-boot` files are interfaces, so GHC's `PprType.hi-boot` can name
`Type.PredType` without creating a build edge. `mhs`'s `.hs-boot` files are real
modules, so the same reference imports `Type` and re-forms the cycle
`Type -SOURCE-> PprType -> Type`. `phase2/hsboot/Type.hs-boot` declares
`PredType` abstractly so `PprType.hs-boot` can SOURCE-import `Type` instead.
The converter learned to emit `{-# SOURCE #-}` between boot modules for the
same reason.


---

### D23 — GHC 4.08.2's compiler typechecks under `mhs`
*2026-09-02.* `mhs` compiles `Main` and reports no errors. Verified with an
`-l` trace rather than taken from the success line alone:

```
184 distinct GHC compiler modules loaded from ghc-4.08.2/ghc/compiler
123 boot-file loads      29 shim loads      473 module loads total
```

The tree has 195 modules once `nativeGen/` is excluded; the 11 not loaded are
unreachable from `Main`. So this is the compiler, not a subset.

This is the Phase 2 goal from `BOOTSTRAP-ANALYSIS.md` — "a `ghc-on-mhs` shim
package ... plus a quilt-style patch series for language-level gaps" — and both
halves are now known to be sufficient *for typechecking*. Code generation is a
separate question and is what Phase 3 needs.

**What it took.** 57 shim modules, 18 patches, 31 converted boot files plus 4
GHC never had, and two generated parsers.

**What the 18 patches actually are**, by cause — the interesting result is how
little of it is GHC being exotic:

| cause | patches | notes |
|---|---|---|
| base drift | 0006, 0012, and shims | `Eval`, Applicative-Monad, `MonadFail`, `catch`, `isAlphanum` |
| GHC-only syntax | 0002, 0005, 0007, 0009, 0010 | `SLIT`, `'c'#`, `_scc_`, `_ccall_` |
| syntax repurposed since | 0014, 0016, 0018 | the composition dot is now record access; `<>` is now Semigroup's |
| latent bugs GHC tolerated | 0011, 0013, 0015 | 9 duplicate items in import lists |
| `.hi-boot` vs `.hs-boot` | (boot files) | four modules need a boot GHC never had |
| mechanical / environmental | 0001, 0003, 0004, 0008, 0017 | trailing spaces, primop hot spots, Latin-1, type punning |

**The single most useful habit**, arrived at the hard way: after fixing the
module that failed, re-run the check across the *whole* tree. Three of my scans
had blind spots that only a tree-wide re-run exposed — duplicate operators
(`(<#)` keyed to an empty string), composition after a closing paren
(`(f <>).g`), and `<>` in the one module lacking `HsVersions.h`. Each would
otherwise have surfaced one compile at a time.

---

### D24 — `hsc` runs; two runtime bugs that typechecking could never have caught
*2026-09-02.* The generated C compiles to a 2.2 MB `hsc` binary that executes
GHC 4.08.2's own code: it parses a source file, reports errors at correct
locations, resolves names, and exits with GHC's own diagnostics. It now stops
only at `Could not find interface file for 'Prelude'`, which is correct
behaviour for a compiler whose libraries have not been built.

Getting there needed two fixes, and **both were semantic bugs in code that
typechecked perfectly**. That is the important result of this phase: the shims
were "done" by every static measure and still wrong.

**1. `fixIO` diverged.** My shim had the obvious-looking

```haskell
fixIO k = fix (\ ~m -> m >>= k)
```

which loops: running the action requires the action, which is its own fixpoint.
`TcMonad` uses `fixIO` for every recursive binding group, so this hit any
module. It presented as `ERR: stack overflow`, and the giveaway was that 50M
stack slots did not help — that is recursion, not depth. The real definition
needs an `IORef` plus `unsafeInterleaveIO`, and now lives once in `GhcCompat`.

**2. The unique supply handed out one unique, forever.** `UniqSupply.mk_supply#`
is a CAF — a nullary `IO UniqSupply`. GHC's `unsafeInterleaveIO` re-executes on
each run, so every node drew a fresh unique. MicroHs's is
`primReturn (primPerformIO ioa)`, which **memoises the thunk**, so the single
shared CAF evaluated once and every node of the tree got the same number:

```
[2013265920, 2013265920, 2013265920, ...]     ten "fresh" uniques
```

Every `Name` in a module then collided, and GHC reported `f` as declared at the
line of the `data` declaration. Giving the recursion a parameter makes each
occurrence a distinct application, hence a distinct thunk — correct under either
semantics.

**Both live in lazy IO.** That is now a known risk area for this port rather
than a surprise: anywhere the original relies on `unsafeInterleaveIO` or
`unsafePerformIO` re-executing, MicroHs's memoising thunks may differ.

**Method note.** Five layers were probed in order — `FastString` interning,
`Unique` packing, `UniqFM` lookup, `removeDups`/`sortLt`, then the supply — and
the first four were *verified correct*. I had a confident theory (32-bit vs
64-bit tag arithmetic in `Unique`) that the evidence refuted. Probing each layer
rather than fixing the plausible one avoided writing corrections to four modules
that had nothing wrong with them.

---

### D25 — What Phase 3 requires, now that the compiler runs
`hsc` cannot compile anything real until GHC's own libraries exist as `.hi`
files. The tarball ships them:

```
ghc/lib/std      47 modules  (29 of them Prel*)   -- the Prelude
hslibs/          lang, data, net, num, concurrent, posix, text, util
```

So Phase 3 is: build `ghc/lib/std` with `hsc`, which will exercise the shims far
harder than the compiler's own source did — the Prelude is exactly where GHC
4.08 reaches into primops and `_ccall_`. Expect more of the D24 species.

Only then does the loop close: GHC emitting C for itself unregisterised, gcc
compiling that, and the result self-hosting.

---

### D26 — GHC, built from the Hugs seed, compiles the Prelude to C
*2026-09-02.* `hsc` compiled `ghc/lib/std/PrelBase.lhs` to 230,611 bytes of
Abstract C plus a 36,649-byte interface. The output is GHC's own unregisterised
via-C form — `INFO_TABLE`, `IFN_`, `ARGS_CHK`, `JMP_`, 712 closures — and the
interface is GHC 4.08's `__interface` format.

Details and the exact pipeline: [`phase3/FINDINGS.md`](phase3/FINDINGS.md).

**Not yet established:** that the C is *correct*. It has not been compiled by
gcc or run. Given that this phase has already produced two bugs which typechecked
and still computed the wrong thing (D24), plausible-looking output is not
evidence of a working compiler.

---

### D27 — The chain reaches native object code
*2026-09-02.* `PrelBase.hc` compiles with gcc to a 492,760-byte ELF object
carrying 1,566 symbols in GHC's expected shape (`__init_PrelBase`,
`PrelBase_append_{closure,entry,info}`, ...).

```
C compiler + Hugs source -> mhs -> hsc -> PrelBase.hc -> gcc -> PrelBase.o
```

Every link in that chain was built from source by the link before it, and the
only pre-existing binary is a C compiler.

Needed one more patch to GHC's own headers (`phase3/patches/0019`): `CLOSURE_TBL`
defines a table as `const StgClosure *[]` while `EDCP_` declares it without the
`const`, which 1999 gcc accepted and modern gcc rejects.

**Still not established:** that the object code *runs*. It has not been linked
against the RTS or executed. Given D24, "compiles and looks right" is not
evidence of correctness.

---

### D28 — `hsc` is the middle of a pipeline, not a compiler you can invoke
*2026-09-02.* The Prelude build stalled at 20/45 modules. Everything doing a
`_ccall_` died with

```
cgPanic: lookupBindC: no info for $wccall_d3I3
```

`DsForeign.lhs:154` desugars a `_ccall_` into a `$wccall` worker plus a wrapper
marked `mkInlineMe`; the code generator only ever expects to see the inlined
form. The inlining is the simplifier's job — and `ghc/driver/ghc.lprl` shows the
driver never lets the simplifier be skipped. Even the *no-optimisation* flag
list contains it:

```perl
@HsC_minusNoO_flags
 = ( '-fsimplify', '[', $Oopt_MaxSimplifierIterations, ']', ... );
```

with `$Oopt_MaxSimplifierIterations = '-fmax-simplifier-iterations4'`. I had been
running `hsc` with an empty Core-to-Core pass list, which no GHC invocation ever
does. Adding `-fsimplify [ -fmax-simplifier-iterations4 ]` took the build from
20/45 to 38/45 in one step.

This is the fifth driver responsibility to reconstruct, after `unlit`, cpp,
`ghc-iface.lprl`, and the shipped `PrelGHC.hi`. The generalisation is worth
stating: **`hsc` is not a standalone compiler.** It is the middle of a pipeline
whose two ends were written in perl, and any behaviour the perl supplied has to
be supplied again — including flags that look like they should default.

A sixth turned up immediately afterwards, and finding it took a wrong turn
first (D29): the driver also extracts `{-# OPTIONS #-}` pragmas from the source
and appends them to the command line. **When something is missing, look in
`ghc.lprl` before concluding anything about GHC's build being broken.**

---

### D29 — `-fno-implicit-prelude` comes from the source, not from position
*2026-09-02. Rewritten after the first answer turned out to be wrong; the first
version is not preserved, but what it claimed is stated below.*

`Time` could not see `Eq`/`Ord` for a `deriving` clause and `IO` could not see
`readIO`, because I was passing `-fno-implicit-prelude` to all 45 std modules
while `ghc/lib/std/Makefile` passes it to none.

Probing with `Prelude.hi` moved aside showed `PrelBase` fails two ways without
the flag:

```
Could not find interface file for `Prelude'
Invalid use of qualified name `Prelude.[]' in the binding for `Prelude.[]'
```

Two mechanisms, both keyed on the flag. `RnNames.lhs:186` adds an implicit
`import Prelude` to every module that is neither `Prelude` itself nor an
explicit importer of it, so `PrelBase` would need `Prelude.hi` — built *from*
`PrelBase`. And `ParseUtil.lhs:435` resolves `[]` to `Prelude.[]` rather than an
unqualified name when the flag is off, so `PrelBase`'s own definition of `[]`
becomes a qualified binding and is rejected.

**The wrong conclusion.** I inferred that the flag must therefore be applied by
position — on until `Prelude` is built, off afterwards — and wrote that GHC
never hit the circularity because its build directory already held interfaces
from the bootstrap compiler. I recorded it as a genuine divergence from a stock
4.08.2 build.

**What is actually true.** The flag is in the *sources*: 31 of the 45 modules
carry `{-# OPTIONS -fno-implicit-prelude #-}`, and `ghc.lprl:2778`
(`check_for_source_options`) scans the de-litified file for `OPTIONS` pragmas
and appends them to the command line. `hsc` does not read pragmas itself. There
is no circularity for GHC to have dodged, and no divergence: the Makefile does
not pass the flag because the Makefile does not have to.

The positional rule also got six modules wrong in the other direction. `Array`,
`Char`, `Maybe`, `PrelArrExtra`, `PrelHugs` and `PrelStable` all declare the
flag but sort *after* `Prelude`, so I compiled them without it. **They compiled
anyway** — which is the whole danger. The flag changes how `[]`, `()` and tuples
resolve; it does not change whether the module typechecks. This is D24's failure
mode again: a wrong setting that produces a plausible artifact.

`compile-lib-module.sh` now reproduces the driver's scan (column 0 only, skip
blank / `#line` / `{-# LINE`, stop at the first other non-empty line, append at
the back) and the positional rule is gone.

**Lesson, and it is the same one as D22.** Both times I had a real mechanism —
here `RnNames` and `ParseUtil`, correctly identified — and built a theory on top
of it that reached past the evidence. Understanding *why* a flag is needed is
not the same as knowing *where it is supposed to come from*, and the second
question is the one that was actually being asked. Before concluding that GHC's
own build was subtly broken, check whether GHC had a mechanism I had not looked
for yet.

**Corollary, now stated as a rule.** `-#include` in those same pragmas is a
driver flag, not an `hsc` flag: it names a C header to inject into the generated
`.hc` (`ghc.lprl:3433`). Pragma options must be *routed*, not forwarded whole.

---

### D30 — Two more header/encoding warts in the 4.08.2 tree
*2026-09-02.*

**`writeMutVarzh` (`phase3/patches/0021`).** `PrimOps.h:648` reads

```c
#define writeMutVarzh(a,v)       (P_)(((StgMutVar *)(a))->var)=(v)
```

The cast is applied to the *left* of the assignment. That is GCC's cast-as-lvalue
extension, removed in GCC 4.0, so `PrelArr.hc` compiled but would not assemble.
Rewritten to cast the value instead. Same family as D-note `mulIntCzh`
(`0020`): 1999 C that modern compilers reject.

**`CPUTime.lhs` is Latin-1.** It carries a single stray `0xA0` (non-breaking
space) inside the comment `-- ::<A0>Integer`. `hsc` runs on mhs, whose file
reader is UTF-8-only and aborts with the bare message `ERR: getb_utf8`. It is
the *only* non-ASCII file in `ghc/lib/std`, and it is not valid UTF-8.

Fixed in the pipeline rather than by patching the source: `compile-lib-module.sh`
transcodes Latin-1 to UTF-8 when the bytes do not already decode as UTF-8. That
is a no-op for pure ASCII, so it costs nothing for the other 44 modules, and it
will cover `hslibs` without needing to find each offending byte by hand.

---

### D31 — Run GHC's own `configure` instead of hand-writing `config.h`
*2026-09-02.* Three Prelude modules (`Time`, `Directory`, `PrelHugs`) compiled to
C but failed at gcc:

```
cbits/timezone.h:78: #error Dont know how to get at timezone name on your OS.
```

`ghc/includes/config.h` was 49 lines I had written by hand in phase 2, covering
only what the RTS headers needed. The `cbits` headers need autoconf `HAVE_*`
probes that were never generated.

**These failures were an improvement, not a regression.** They appeared only
once I wired up the `-#include` OPTIONS (D29): before that the headers were
never included at all, so the foreign-call prototypes were simply absent. On
x86-64 an implicitly-declared function returning a pointer is assumed to return
`int`, and the pointer is truncated. The version that "passed" was the dangerous
one — D24 again.

The tarball ships `configure` and `mk/config.h.in` with all 177 probes, so the
fix is to run GHC's own machinery rather than guess values. `phase2/mkconfig.sh`
now does that, then transcribes `ghc/includes/Makefile`'s `$(H_CONFIG)` rule to
prepend the platform defines. Result: 153 defines instead of 49, including
`HAVE_TM_ZONE 1`, `TYPE_TIMEZONE time_t`, `SIZEOF_VOID_P 8`.

**A latent bug it caught.** My hand-written file had `#define LEADING_UNDERSCORE 0`,
but `MachMisc.lhs:62` tests it with `#ifdef` — where *defined as zero* is true.
`hsc` was built believing ELF symbols take a leading underscore. It never bit
because the native code generator is off, but it was wrong, and I would not have
found it by reading my own file: defining a flag to 0 to mean "false" is only
correct if every reader uses `#if`.

Getting a 1999 configure to run needed four accommodations, each a real
incompatibility rather than a workaround:

1. **`config.sub` predates x86-64** (patch 0023). It rejects the triple
   outright. Added `x86_64` beside `i[34567]86`.
2. **`configure` has a platform whitelist** (patch 0024). Added a genuine
   `x86_64-unknown-linux` case rather than masquerading as i386 — no 1999 code
   has an `x86_64_TARGET_ARCH` branch, so every arch-specific path correctly
   switches off, which is what unregisterised means. Claiming i386 would have
   selected 32-bit paths *and* re-enabled the NCG. `configure.in` is patched to
   match, but the generated `configure` is what runs: autoconf 2.72 cannot
   safely regenerate a 2.13-era input.
3. **The probes are pre-C99.** They use `main(){return(0);}`, and implicit-int
   is now a hard error, so every probe failed with "C compiler cannot create
   executables". The probes are compiled `-std=gnu89`. This affects only the
   probe programs; link-based probes still fail honestly on a missing symbol.
4. **`configure`'s happy version test is broken for modern happy.** It does
   `expr "$version" "<" 1.6`, a *string* comparison — so `1.19.5` sorts before
   `1.6` and is rejected as too old. happy was 1.8 in 2000, so the bug could not
   fire. The correct probed value is seeded into the autoconf cache, which makes
   configure skip the branch holding the broken test.

Item 4 is a genuine GHC bug, like the `mulIntCzh` and `writeMutVarzh` ones in
D30 — but in the build system rather than the compiler, and triggered by a
*newer* dependency rather than a newer compiler.

---

### D32 — `-#include` values come in three shapes
*2026-09-02.* Wiring up the `-#include` OPTIONS (D29) exposed that the values are
not all the same kind of thing. Across `ghc/lib/std` they take three forms:

```
<sys/stat.h>            a system header
../../rts/Schedule.h    relative to the module's own directory
Assembler.h             relative to ghc/includes
```

My first pass prefixed every one with the source directory, which turned
`<sys/stat.h>` into a literal path containing angle brackets:

```
fatal error: .../ghc/lib/std/<sys/stat.h>: No such file or directory
```

`compile-lib-module.sh` now resolves each value once, at extraction time, and
writes the resolved path to the sidecar — so both build scripts stay simple and
cannot disagree about resolution.

Small, but it makes the point that reproducing a driver flag means reproducing
its *semantics*, not just forwarding its text. The same mistake in D29 was
forwarding `-#include` to `hsc`, which has no such flag at all.

---

### D33 — The Prelude is complete: 45/45 to object code
*2026-09-02.* All 45 modules of `ghc/lib/std` now compile from Haskell source to
ELF object files with the bootstrapped `hsc`: 13MB of objects, 4,850 defined
symbols.

```
C compiler + Hugs source -> mhs -> hsc -> 45 .hc -> gcc -> 45 .o
```

Progress across this phase went 1 -> 9 -> 13 -> 20 -> 38 -> 43 -> 45, and the
large jumps were not incremental fixes. 20 -> 38 was the simplifier pass (D28)
and 43 -> 45 was the `-#include` resolution (D32). Nearly every plateau was a
single missing piece of driver behaviour, not a pile of independent problems.

`PrelBase.o` is now 322,488 bytes, against the 492,760 recorded in D27. The
difference is the simplifier: D27's object was built with an empty Core-to-Core
pass list, which no real GHC invocation uses. The earlier artifact was not
wrong so much as unoptimised in a way GHC never produces.

**Still not established:** that any of this *runs*. Nothing has been linked
against the RTS or executed. Every claim above is about compilation succeeding.

---

### D34 — The 64-bit paths in `hslibs/lang` were never compiled
*2026-09-02. User asked to repair them, patch by patch, accepting that the
result is 4.08.2-plus-a-64-bit-port rather than stock 4.08.2.*

`Int.lhs` and `Word.lhs` each carry a `#if WORD_SIZE_IN_BYTES == 8` section —
97 and 129 lines — that opens only on a 64-bit platform. GHC 4.08.2 lived on
32-bit x86, so on the machines that mattered these were skipped entirely, and
they had rotted. Neither module can be avoided: `PrelRules.lhs` imports `Word64`
and `Ctype.lhs` imports `Int32`. (The many `Int64Rep`/`Word64Rep` hits elsewhere
in the compiler are GHC's internal `PrimRep` constructors, not these types.)

Eight defects, repaired by mirroring what each file already does for its 32-bit
types rather than by inventing:

| Where | Defect | Repair |
|---|---|---|
| `Int.lhs:951` | `intToInt32#` redefined; both guards open at 64 bits | drop it — the Int32 section's definition is already active |
| `Int.lhs:954` | `intToInt32# w#`, and `w#` is unbound | `i#` |
| `Int.lhs:960` | `instance Ord Int32` whose methods match `I64#` | `Ord Int64` — `Ord Int32` already exists at 742, and `Ord Int64` existed *only* in the 32-bit branch, so one relabel fixes a duplicate and a gap at once |
| `Int.lhs:969` | `abs x = absReal` — argument dropped | `abs = absReal`, as the Int32 instance writes it |
| `Int.lhs:1006` | `complement = negateInt#` — arithmetic negation, not bitwise | xor with all-ones, copying the Int32 instance at 879 |
| `Word.lhs:1114` | `W32` missing its `#` | `W32#` |
| `Word.lhs:1128` | `intToWord64#` used three times, never defined | define as `int2Word#`, matching the two neighbouring identity conversions |
| `Word.lhs:1156` | `negate` masks against `0x100#` — the *Word8* constant | two's-complement negation, as the natural-width branch does for Word32 |
| `Word.lhs:~1205` | `W64#` closed early; `or#` applied to a Word64; stray `)` | reshape to match the Word32 `rotate` |

Two of these — `complement` and `negate` — were semantically wrong rather than
ill-formed. They would have compiled on a machine that reached them and computed
the wrong answer, and `PrelRules` uses `Word64` for constant folding, so a wrong
answer there is a wrong answer baked into every program the compiler builds.

That the file's own 32-bit instances supplied the correct form for every one of
these is what made the repair mechanical rather than a matter of taste.

---

### D35 — Every interface was stamped with the wrong package
*2026-09-02.* `Bits` failed with

```
Failed to find interface decl for `PrelNum.negate' from module `PrelNum'
```

although `PrelNum.hi` plainly exports `negate` and declares it in `class Num`.
D22's rule applies — when the error names something that demonstrably is there,
suspect the message. So rather than theorise I cut it to five lines:

```haskell
{-# OPTIONS -fno-implicit-prelude #-}
module TNeg where
import PrelBase
f :: Int -> Int
f i = (-i)
```

That reproduces it. `(-i)` desugars to `negate`, looked up by original name. Then
two probes localised it: adding `import PrelNum` makes it compile, and so does
`import PrelNum ()` — merely *naming* the module is enough. So the interface was
readable and the failure was specific to the on-demand load path.

The cause was in the interface header:

```
__interface "Main" PrelNum 1  408 where
```

`ghc/lib/std/Makefile:29` sets `PACKAGE = -package-name std`, and
`hslibs/mk/target.mk:125` sets `-package-name $(HSLIB)`. I passed neither, and
`CmdLineOpts.lhs:397` defaults `opt_InPackage` to `SLIT("Main")`. Every one of
the 45 interfaces claimed to be in package `Main`, so cross-package lookup had
nothing to work with.

**This is the seventh driver responsibility**, and like `-#include` in D32 it is
a *translation*, not a forward: `ghc.lprl:3140` turns `-package-name std` into
hsc's own spelling, `-inpackage=std`. Searching hsc for `-package-name` finds
nothing at all.

The pattern across D28, D29, D32 and D35 is now unmistakable. Four times the
missing piece was something the perl driver did on the way in, and three of those
four were invisible from `hsc`'s own flag list.

---

### D36 — `PrelAddr.lhs` branches on a macro it never defines
*2026-09-02.* Repairing `Word.lhs` bottomed out in a type error that was not in
`Word.lhs` at all:

```
Couldn't match `Word64#' against `Word#'
    In the first argument of `W64#', namely `w#'
```

`PrelAddr.lhs:69` declares the type:

```haskell
#if WORD_SIZE_IN_BYTES == 8
data Word64 = W64# Word#
#else
data Word64 = W64# Word64#
#endif
```

and `PrelAddr.lhs` contains **no `#include` at all**. `WORD_SIZE_IN_BYTES` is
defined in `MachDeps.h`; the driver's cpp flags (`ghc.lprl:387`) define only
`__HASKELL__`, `__HASKELL1__`, `__GLASGOW_HASKELL__`, `__HASKELL98__` and
`__CONCURRENT_HASKELL__`. So the macro is undefined, cpp reads it as 0, and the
32-bit branch is taken — while `Word.lhs`, which *does* include `MachDeps.h`,
takes the 64-bit branch. The two disagree about the representation of `Word64`.

**Why this survived 25 years.** On 32-bit the omission is invisible, because
"undefined" and "32-bit" select the same branch. The bug is only reachable where
the two answers differ, and there the module that declares the type is the one
getting it wrong.

Swept the rest of `ghc/lib/std` and `hslibs/lang` for the same shape — a file
using `WORD_SIZE_IN_BYTES`, `INT_SIZE_IN_BYTES`, `ADDR_SIZE_IN_BYTES` or
`SIZEOF_*` without including a header that defines it. `PrelAddr.lhs` is the
only one; `Addr`, `Int`, `NativeInfo`, `Storable` and `Word` all include
`MachDeps.h`. So this is an isolated omission, not a pattern.

Fixed by adding `#include "MachDeps.h"`, which is what every sibling does.

Also aligned the cpp defines with `ghc.lprl:387` exactly: I had been passing
three of the driver's five and was missing `-D__HASKELL__=98` and
`-D__HASKELL98__`.

---

### D37 — `-static`, and the flag whose failure mode is a pun
*2026-09-02.* With `Word.lhs` finally typechecking, it produced C that gcc
rejected:

```
InfoMacros.h:615: #define DLL_SRT_ENTRY(x) no-can-do
Word.hc:312: DLL_SRT_ENTRY(PrelShow_showString_closure)};
error: 'no' undeclared here (not in a function)
```

`DLL_SRT_ENTRY` is deliberately defined as text that cannot compile: reaching it
means the code generator decided a cross-module closure lives in a *different
DLL*, which is meaningless in this build. The cure is `-static`, which
`ghc/lib/std/Makefile:46` and `hslibs/mk/target.mk:88` both add and which
`ghc.lprl:1676` passes straight through to `hsc`.

That is the **eighth** build responsibility reconstructed, and the second (after
`PACKAGE`, D35) that lives in a Makefile rather than the driver. The list so
far: `unlit`, cpp, the interface post-processor, the shipped `PrelGHC.hi`, the
mandatory simplifier pass, `{-# OPTIONS #-}` extraction, `-package-name` (as
`-inpackage`), and `-static`.

Worth noting how it announced itself. The error named neither the flag nor the
concept — it was a C parse error about an undeclared variable `no`, from a macro
body that is a hyphenated English phrase. Nothing about the message points at
static linking. What made it findable was that `InfoMacros.h` says plainly, by
being unusable, "you should not be here."

**The whole Prelude built without `-static`.** 45 modules, all the way to object
code, and the flag was missing throughout. Whether that output was *correct* is
a separate question from whether it compiled, and I do not know the answer for
the earlier artifacts. Everything is being rebuilt with the flag.

---

### D38 — Running tally of the 64-bit repair
*2026-09-02.* Continuation of D34. The defect count kept climbing as each fix
uncovered the next, which is what a section that has never been through a
compiler looks like. Beyond the eight in D34:

| Where | Defect |
|---|---|
| `Word.lhs` | `wordToWord32#` and `wordToWord64#` defined twice — once in the Word32 section, once in the Word64 section, both open at 64 bits |
| `Word.lhs` | `word64ToInteger`, `integerToWord64`, `intToWord64`, `word64ToInt` exported and given signatures, but defined only in the 32-bit branch |
| `Word.lhs:1179` | `toInteger` calls the raw primop `word2Integer#`, which returns an unboxed tuple; every sibling uses the boxed wrapper `word2Integer` |
| `Word.lhs` | `word64ToWord32` given a second type signature |
| `Word.lhs` | `mod` binds `x`/`y` but its guard reads `y#`, and hands the unboxed `x` to `divZeroError` |
| `Word.lhs`, `Int.lhs` | `pow2_64#` guarded only by `#ifndef __HUGS__`, though it is built from the `Int64#`/`Word64#` emulation primitives and its only use is 32-bit-only |
| `Word.lhs` | `wordToWord64#`, `word64ToWord#`, `intToWord64#` have no type signatures, so they generalise at kind `*` and cannot take a `Word#` |
| `Int.lhs:751` | `negate` binds `x` and then uses `x'` |
| `Int.lhs:956` | `Eq Int64` calls `eqInt#`/`neInt#`, which do not exist |

Eighteen so far. Every repair was taken from the same file's own 32-bit
instances rather than invented — the Int32 `Bits` instance supplied the right
`complement`, the Word32 `rotate` supplied the parenthesisation, the `Eq Int32`
instance supplied `==#`/`/=#`. That is what kept this mechanical.

The two that matter most are still the semantic pair from D34: `complement` as
arithmetic negation, and a 64-bit `negate` masking against the Word8 constant.
Those would have compiled and returned wrong numbers.

---

### D39 — hslibs/lang builds: 24/24
*2026-09-02.* With `Int.lhs` repaired the whole cascade cleared in one step —
18 modules that had been failing on missing interfaces compiled without further
change, confirming they were never independently broken.

The last one, `IOExts`, wanted `stgio.h`, which is neither beside the module nor
in `ghc/includes`. `hslibs/lang/Makefile:20` says why:

```make
IOExts_HC_OPTS += -I$(GHC_IO_INCLUDE_DIR)
```

with `GHC_IO_INCLUDE_DIR = $(GHC_LIB_DIR)/std/cbits` (`hslibs/mk/boilerplate.mk:37`).
A per-module include path, for exactly one module in the package. Added
`ghc/lib/std/cbits` to the `-#include` resolver's search order (D32), which is
where that knowledge belongs — it now covers all four shapes those values take.

Full state of the libraries, verified by checking for a non-empty `.o` per
module in each order file rather than by reading the build log's summary line
(the `IOExts` run started mid-list, so its "compiled 17" counts only the tail):

```
ghc/lib/std    45/45 modules -> .hi + .hc + .o
hslibs/lang    24/24 modules -> .hi + .hc + .o
              69 objects, 17MB, 7,278 defined symbols
```

That is every library module `hsc` imports. What remains is the RTS (36 C files)
and the link.

---

### D40 — The RTS compiles: 45/45
*2026-09-02.* `phase3/build-rts.sh` builds `ghc/rts/*.c` plus `hooks/*.c` — the
`SRCS_RTS_C` of `ghc/rts/Makefile`, minus the Windows-only `RtsDllMain.c` and
the `parallel/` directory, which belongs to the "mp" way. 45 objects, 168
defined symbols including `main`, `GarbageCollect`, `initStorage`, `newCAF`.

**GMP was not the obstacle it looked like.** `ghc/rts/Makefile` builds its
bundled 1999 copy only `ifneq "$(HaveLibGmp)" "YES"`, and configure had decided
`No`. But that probe is `AC_CHECK_LIB(gmp, mpz_fdiv_qr)`, which declares
`char mpz_fdiv_qr();` and links against that name — while in modern GMP
`mpz_fdiv_qr` is a macro for `__gmpz_fdiv_qr`. The probe cannot succeed on any
current library regardless of whether one is installed. Confirmed the system GMP
works by compiling a real `mpz_fdiv_qr` call, so the build takes GHC's own
`HaveLibGmp=YES` path and the bundled GMP is never touched.

That is the third 1999-vs-now autoconf failure, after the pre-C99 probes and the
string version comparison (D31). All three share a shape: the probe tests a
proxy for the thing it cares about, and the proxy has since stopped tracking it.

**One real C problem, 32 times.** The cast-as-lvalue extension again (D30), now
in the RTS:

```c
(StgClosure *)mvar->head = evacuate((StgClosure *)mvar->head);
```

My first sweep regex found 6 and missed 26, because it only matched a cast
applied to a bare identifier and most of these apply it to a field or a
dereference. Rather than widen the regex and hope, I let gcc enumerate them with
`-fmax-errors=100`, which is authoritative in a way my pattern was not — the
same lesson as the three earlier scanners with blind spots, learned again.

They were then rewritten mechanically rather than by inferring 32 declared
types. GCC's `(T)lv = v` means "reinterpret lv's storage as T and assign", whose
standard-C spelling is `*(T*)&lv = v`. That transformation is meaning-preserving
and needs no knowledge of the left-hand side's type. All of these are
pointer-sized, which is why the extension worked here originally.

---

### D41 — It links, and compiled Haskell runs
*2026-09-02.* `main = return ()`, compiled by the bootstrapped `hsc` and linked
against the bootstrapped Prelude, hslibs, RTS and cbits, **runs and exits 0**.

```
C compiler + Hugs source -> mhs -> hsc -> .hc -> gcc -> .o -> ld -> a.out -> runs
```

The whole chain executes: the RTS initialises, the scheduler starts a thread,
`StgRun` enters compiled Haskell, and the program terminates cleanly. Up to now
every claim in this log was about *compilation* succeeding. This is the first
evidence that the generated code is executable at all.

Four things were needed to get from "45/45 objects" to a working link:

1. **The RTS has hand-written Abstract C.** `ghc/rts/Makefile`'s `SRCS_RTS_HC`
   lists seven `.hc` files holding the STG machinery itself. Without them the
   link had 22,619 undefined references; with them, 9.
2. **`hslibs/lang` has its own cbits.** One file, `PackedString.c`.
3. **`PrelHugs.o` must not be linked.** `ghc/lib/std/Makefile:38` filters it out
   of `LIBOBJS` unconditionally. It is the Hugs interop shim and the only thing
   besides `IOExts` that wants the adjustor.
4. **`-O` is mandatory, not a preference.** `Stable.h` declares
   `deRefStablePtr` and friends `extern` and then defines them `extern inline`,
   which under GNU89 emits no out-of-line copy — and no `.c` file provides one.
   Every call must be inlined. At `-O0` the link fails with undefined
   references; without `-std=gnu89` it fails instead with *multiple* definitions,
   because C99 inverted what `extern inline` means. GHC compiled everything
   `-O` (`GhcLibHcOpts=-O`), so this is what it always relied on.

Two gaps were filled rather than found:

- **`__encodeFloat`** (patch to `PrimOps.h`). When `StgFloat` *is* `StgDouble`
  — true whenever `SIZEOF_DOUBLE == SIZEOF_VOID_P` — `StgPrimFloat.c` compiles
  only the Double versions, but the code generator still emits calls to the
  Float ones. The header already aliases the *decode* direction
  (`decodeFloatzh_fast` -> `decodeDoublezh_fast`); the encode direction was
  simply left out. Added the matching aliases.
- **The adjustor** (`phase3/rts-x86_64-stubs.c`). `Adjustor.c` implements
  `createAdjThunk`/`freeHaskellFunctionPtr` only for i386 and sparc, with the
  comment "Heavily arch-specific, I'm afraid..". These generate machine code at
  runtime so a Haskell closure can be passed to C as a function pointer. x86-64
  did not exist in 1999. Stubs that `barf` are the honest representation: the
  facility is genuinely absent, not quietly broken. Writing a real x86-64
  adjustor would mean inventing a piece of GHC that never existed.

---

### D42 — Where it stands: 64-bit assumptions in a 1999 runtime
*2026-09-02.* `putStrLn` does not yet work. Debugging it has produced a run of
bugs that all share one shape, and the shape is worth stating before the list.

**The pattern.** GHC 4.08.2 targets 32-bit machines. Every place where "32-bit"
and "the value that is actually correct" happened to coincide is a place where
the code is silently wrong on x86-64 — and the platform is unknown to 4.08.2, so
nothing selects a working alternative. Three of these were found earlier
(`LEADING_UNDERSCORE` defined as 0 and tested with `#ifdef`, D31; `PrelAddr.lhs`
branching on a macro it never includes, D36; `mulIntCzh` and `writeMutVarzh`,
D30). Debugging one `putStrLn` has produced three more:

**1. Primop returns went to the wrong place.** `PrimOps.hc` selects its
unboxed-tuple return convention with `#if defined(REG_R8)` … `#elif
defined(REG_R1)` … `#else /* 0 Regs available */`. Those test whether STG
registers are *pinned to machine registers*. But the compiler chooses its
convention from `MAX_REAL_VANILLA_REG`, which `MachRegs.h:473` defaults to **8**
for any platform it has no entry for. So on x86-64 the compiler returns results
in R1 while the RTS pushes them on the stack. Confirmed from both sides:
`cd3v_ret` in `PrelHandle.hc` reads `R1.p`, and `RET_P` under "0 Regs" expands to
`PUSH_P(1,a)`. The symptom was `mkForeignObj` appearing to return the pointer it
was given rather than the object it allocated. Fixed by selecting the
register-based convention when there is no register mapping at all, which is
what `MAX_REAL_VANILLA_REG`'s own default already implies.

**2. A loop counter underflowed into four billion iterations.** `Updates.hc:386`:

```c
for (i = Words-1; i >= 0; i--)
    Sp[i+(sizeofW(StgUpdateFrame))] = Sp[i];
```

`Words` is `nat` — `unsigned int`, so 32 bits (`RtsTypes.h:14`) — while `i` is
`I_`, a `long`. When `Words` is 0, `Words-1` is evaluated in unsigned int and
gives `0xFFFFFFFF`, which widens to **+4294967295** in the 64-bit signed `i`.
On 32-bit, `I_` is also 32 bits, the same expression is `-1`, and the loop is
correctly skipped. The bug cannot fire on the platform GHC was written for.
Fixed by casting before the subtraction. Swept the RTS for the same pattern:
exactly two sites, both in this function.

**3. Still open.** Execution now reaches
`PrelHandle_getBModezuzu_info` and jumps *into* an info table instead of its
entry code.

**What this means for scope.** Each fix reveals the next assumption, and the
supply is not obviously exhausted. This is no longer bootstrapping GHC 4.08.2 —
it is porting its runtime to a word size it was never written for. That is a
legitimate project but a different one, and open-ended, so it is a decision for
the user rather than one to make by continuing.

**What is nonetheless established.** The bootstrap chain itself is complete and
demonstrated: every library and runtime source compiles, links, and produces an
executable that runs compiled Haskell to a clean exit. The failures now are in
1999 C meeting a 64-bit machine, not in the bootstrap.

---

### D43 — Closing the project: what was built and what it cost
*2026-09-02. User asked to stop here and write it up rather than continue into a
64-bit port of the runtime.*

**Established.** A Haskell compiler built on a machine with no Haskell compiler,
from a C compiler and Hugs source:

```
C compiler + Hugs -> mhs -> cpphs, happy -> hsc -> .hc -> gcc -> ld -> runs
```

`main = return ()` compiles through the bootstrapped `hsc` and runs to a clean
exit. 45/45 Prelude modules, 24/24 `hslibs/lang`, 52/52 RTS objects and 42 cbits
all build; they link into a 6MB executable.

**Not established.** That a program doing I/O works. `putStrLn` reaches the
buffering setup for `stdout` and dies on a 64-bit assumption in the 1999
runtime. D42 states the open problem precisely.

**Reproducibility, checked rather than assumed.** 30 patches against the
pristine tarball; applying them to a clean extraction reproduces the working
tree byte for byte. This invariant was broken twice during the project without
being noticed — once by an edit that existed in the tree and in no patch (D-note
in `Ctype.lhs`), once by 43 patch hunks that edited LaTeX prose rather than
code. Both were found by *checking* the invariant, not by remembering to
maintain it. The check is cheap and the memory is not reliable.

**The shape of the work.** Of the 30 patches, exactly **one** is about
bootstrapping — `unlit` rejecting a trailing space. The other 29 are a 1999
program meeting a 2026 toolchain (Haskell that stopped being legal, C that
stopped being legal) and a machine word twice the size it expects. The
bootstrapping problem, the thing this project set out to solve, turned out to be
the small part. `PATCHES.md` has the breakdown.

**The most useful single idea.** `hsc` is not a compiler you can invoke; it is
the middle of a pipeline whose two ends were written in perl. Eight separate
responsibilities had to be reconstructed, three of them invisible from `hsc`'s
own flag list. Every plateau in this project — 1, 9, 13, 20, 38, 43, 45 modules
— broke on finding one more of them, not on incremental fixes.

**Recurring lessons, in the order they were learned the hard way.**

- A patch that applies cleanly and changes meaning is the dangerous failure
  (D21: `_scc_` removal ate `main`'s body).
- When an error names something that demonstrably *is* there, suspect the
  message before building a theory around it (D22, and again in D35).
- Four scanners of mine had blind spots. When a compiler can enumerate the thing,
  do not grep for it (D40: 6 found by regex, 32 by `-fmax-errors=100`).
- After fixing the failing case, re-run the check tree-wide. Three separate
  sweeps found more instances than the failure that prompted them.
- Understanding *why* something is needed is not the same as knowing *where it
  is supposed to come from*, and the second is usually the question being asked
  (D29, the wrong turn that cost the most).

---

## D44 — Is GHC 6.x within mhs's reach? Measured, not estimated
*2026-09-03.*

**Question.** Whether the mhs entry point could be moved from 4.08.2 to 6.x,
which would be attractive because 6.2 is the first GHC with an x86-64 port —
the entire class of 64-bit rot that produced 29 of this project's 30 patches
would largely disappear.

**Method.** Compile each tree's compiler with `mhs -c -fno-code`, in the
dependency order from `build-order.py`, sharing the `-C` cache (D22: any other
shape mis-binds boot modules). Same shim set, same cpp defines for both trees.
4.08.2 is the control: phase 2 built `hsc` from it, so a correct harness must
score near 100% on it. Scripts: `phase2/probe-ordered.sh`,
`phase2/scan-classify.py`. Raw data: `build/probe-{4.08.2,6.0b}.tsv`.
Measured on 6.0; no 6.2 tarball here, but 6.0 is one minor release earlier and
structurally identical for this question.

**Result.**

| | 4.08.2 (control) | 6.0 |
|---|---|---|
| modules | 195 | 264 |
| compiled | **190 (97.4%)** | **12 (4.5%)** |
| failed | 5 | 250 + 2 timeouts |

Of the control's 5 failures, 4 are defects in `hiboot2hsboot.py`'s output
(`CgExpr.hs-boot`, `TcMatches.hs-boot`), not in the tree.

**Cause, and it is a single macro.** `HsVersions.h`:

    4.08.2:  #define SLIT(x)  (FastString.mkFastString x)      -- boxed String
    6.0:     #define SLIT(x)  (FastString.mkLitString# (x#))   -- unboxed Addr#
             #define FSLIT(x) (FastString.mkFastString# (x#))

~2,900 call sites across ~125 files. Unlike `GLAEXTS`/`DATA_BITS`, which
`HsVersions.h` maps back to pre-hierarchical names under `__GLASGOW_HASKELL__
< 504`, `SLIT`/`FSLIT` are defined **unconditionally** — there is no branch to
select. This is the construct D5 called lexical and unshimmable. In 4.08.2 it
appeared only in happy's generated parsers, which phase 1 fixed by regenerating
them; hand-written compiler source cannot be regenerated.

**The failure is not concentrated.** 129 distinct root-cause modules; only 6
are in excludable directories (`ghci/`, `ndpFlatten/`). Excluding GHCi and
Template Haskell removes under 5% of the problem. The rest is `Var`, `CoreSyn`,
`HsSyn`, `Outputable`, `TcType`, `Simplify`, `PrimOp`, `Module`.

**Conclusion.** 6.x is out of reach until *mhs* learns unboxed string literals.
That is a change to MicroHs, not to GHC. Everything else feared beforehand is
cheaper than estimated: 6.0 has 27 boot modules (not 83 — three CPP format
variants of each file were counted separately), its `.hi-boot-6` files are
already Haskell so no translator is needed, and the `GHC.IOBase`/`GHC.Handle`
imports are the `>= 504` branch that `-D__GLASGOW_HASKELL__=408` never takes.
The ladder route is unchanged and still better: finish the 64-bit RTS port, then
4.08.2 -> 5.00.2 -> 6.0 -> 6.2 on paths the maintainers tested.

**Five harness bugs, all of which made both trees look worse than they are.**
Recorded because the first three "results" of this probe were pure artefact:

1. `config.h` line 37 is a form feed (autoheader page break); cpphs `--strip`
   leaves it and mhs's lexer rejects it.
2. `-DHscIfaceFileVersion` is a per-module define in `ghc/compiler/Makefile`;
   without it `Constants.lhs` fails and ~140 modules cascade.
3. 6.0's `main/Config.hs` is generated by the Makefile and absent from the
   tarball; transcribed into `phase2/gen-6.0/Config.hs`.
4. The driver's five `@HsSourceCppOpts` defines were missing, so `HsVersions.h`
   expanded `FMAP` to `map` instead of `fmap` and 62 modules failed to
   typecheck. These were already reconstructed in phase 3 (D32) and not carried
   over — the same lesson as the whole project: with GHC, the Makefile and the
   perl driver *are* part of the compiler.
5. Four hand-repaired `.hs-boot` files in `phase2/hsboot/` were clobbered by
   generated ones; the broken `InstEnv.hs-boot` alone took out 69 modules.

Control trajectory as these were fixed: 9/153 -> 28/96 -> 42/115 -> 190/195.

**Process note.** `phase2/probe-ordered.sh` was edited while a shell was still
executing it. sh reads scripts incrementally, so the trailing summary line was
parsed from a shifted offset and died with "unexpected EOF". The loop had been
parsed whole and ran correctly — all 195 rows are present and uniform — but the
run reported no summary. Do not edit a script that is running.

---

## D45 — D44 overturned: the entry point moves to GHC 6.2.2
*2026-09-09.*

**What changed since D44.** D44 measured 6.0 at 12/264 modules and concluded
6.x was out of reach until mhs learned unboxed string literals. That turned out
to be wrong in the useful direction: `SLIT`/`FSLIT` were redefined over boxed
`String` in `HsVersions.h` (with a `LitString` shim in `FastString`) and the
6.0 tree went 12 → 116 → 206 → 214 of 264 between 3 and 9 September, with
`Main` typechecking. The full count is in `build/probe-6.0-run3-final.tsv`;
of the 50 failures, 31 are ilxGen test programs that should never have been in
the order file. The work is captured in `build/6.0-run2.patch` (regenerated as
`build/rebase622/6.0-current.patch`: 103 files, 244 hunks).

**Why 6.0 is the wrong target anyway.** 6.0 has no x86-64 entry: the only
`x86_64` in its tree is the `config.h` we generated. An x86-64 build of 6.0 is
an "unknown platform" build exactly as 4.08.2 was (D42), and the 4.08.2 chain
stopped on that class of bug. 6.2 is the first GHC that knows x86-64 exists.
Three measurements on 9 September, all in `build/`:

1. *History* (`research-6.2-x86_64.md`). 6.2.x on x86-64 worked in exactly one
   configuration, unregisterised via-C, which is the one we produce. Debian,
   Ubuntu, Gentoo and OpenBSD shipped it; it self-hosted and passed the
   testsuite on OpenBSD amd64. Registerised, NCG and GHCi arrived in 6.4/6.4.1.
   Known 6.2.2 defects on x86-64: `MBlock.h` `HEAP_ALLOCED` uses the low 32
   bits (breaks after 4GB allocated; fixed by one 6.4 commit), adjustors barf.
2. *RTS* (`rts622/FINDINGS.md`). 6.2.2's `configure` runs on x86-64 with no
   help (`--enable-hc-boot --enable-hc-boot-unregisterised`); 78/78 RTS objects
   compile with gcc 16 after **two** patches (58 cast-as-lvalue sites, the D40
   class, and one `static`/`extern` mismatch in `GC.c`); a C driver initialises
   the RTS, allocates 12.8MB across two major GCs and exits 0. No 64-bit-size
   failures, no GMP problem, no Adjustor stub. `AutoApply.hc` is generated by
   a Haskell program mhs compiles. The D42 return-convention mismatch is fixed
   by construction: 6.2.2's `PrimOps.hc` and `CgRetConv.lhs` both select on the
   register *count*.
3. *Rebase* (`rebase622/FINDINGS.md`). Of the 217 edit hunks made for 6.0, 171
   apply to 6.2.2 unchanged, 4 need a minute, 8 are obsolete, 34 belong to two
   files 6.2.2 replaced outright: `parser/Lex.lhs` (now alex-generated
   `Lexer.hs` with `Addr#` tables) and `utils/StringBuffer.lhs` (API shrank to
   11 functions). Boot files (30/32 verbatim), shims (16/16 still needed, plus
   a 3-line `CForeign`), `HsVersions.h` and `build-order.py` carry over.

**Decision.** Drop 6.0. mhs compiles 6.2.2's compiler proper, configured for an
x86-64 target so its `.hc` output has 8-byte words; 6.2.2's own RTS and
libraries take it from there. The ladder 4.08.2 → 5.00.2 → 6.0 → 6.2 collapses
to one rung, and the 4.08.2 64-bit port (D42) is no longer on the path.

**Overturned by:** the 6.2.2 probe (label `6.2.2-run1`) stalling on something
the 6.0 work did not meet — the alex lexer tables are the known unknown — or
compiled 6.2.2 Haskell dying in the runtime the way 4.08.2's did.

**Not yet shown.** Runtime correctness under compiled Haskell (a C driver
exercises the allocator and GC, not the STG machine), and that the compiler
proper's `Constants`/`Config` for an x86-64 target produce `.hc` files this
RTS accepts.

## D46 — The 6.2.2 probe passes: Main typechecks, 226/235
*2026-09-10.* The overturn test set in D45 was "the 6.2.2 probe stalls on
something the 6.0 work did not meet". It did not. One full ordered pass of
`mhs -C -c -XCPP` over 6.2.2's compiler (label `6.2.2-run1`, tree
`build/ghc-6.2.2-run1`, results `build/probe-6.2.2-run1-final.tsv`):

| | 6.0 (D44, best) | 6.2.2 run1 |
|---|---|---|
| modules in order | 264 | 235 |
| OK | 214 | 226 |
| FAIL | 50 (31 ilxGen tests) | 9 |
| `Main` | OK only in a trunk rerun | OK, row 233 of the ordered pass |

The nine failures are the same classes 6.0 had and none is on `Main`'s import
path: `PrimPacked` (shadowed by the FastString shim, unused), five GHCi bytecode
modules plus `InteractiveUI` (`GHC.Ptr`, GHCI is off), and the dead `IlxGen`
and `JavaGen` back ends.

**The known unknown was small.** The alex-generated `Lexer.hs` carried its DFA
as `Addr#` string literals indexed with `indexInt16OffAddr#`. Those tables are
16-bit little-endian signed entries with no big-endian branch, so
`build/lexer622/convert-lexer.py` keeps the literals and decodes them once at
startup into a boxed `Array Int Int`; the DFA and every token action are
untouched. A token-dump driver built with mhs lexes a sample program, 79
MicroHs library modules and the lexer's own source with the expected tokens and
spans. The new `StringBuffer` is a 118-line shim over `Array Int Char`. Parsers
and primop tables were regenerated with our own happy and genprimopcode
(`build/gen622/regen.sh`); against 6.0's inputs the same recipe reproduces all
14 files byte for byte.

**New edits 6.2.2 needed beyond the 6.0 patch** (all small, all marked `mhs`):
two signature/binding splits (`SysTools.getBaseDir`,
`TcRnMonad.getBannedProcLevels`), two double commas (`CgHeapery` exports,
`RnSource` imports), one empty statement after `do {` in the new `TcArrows`,
two new `_scc_` pragmas, a `#error GHC >= 5.00` guard in `SysTools`, and the
6.2.2 `THSyntax` in place of 6.0's. Patch: `build/6.2.2-run1.patch`, 101 files,
187 hunks, generated files excluded.

**One bug found that 6.0 also has.** Under the shims `FastInt` is a lazy `Int`,
so `SrcLoc` built one thunk per character while lexing and overflowed the mhs
stack on lines past ~50K columns. Strict `!FastInt` fields in `SrcLoc` fix it.

**Method note.** A `-C` cache restart at row N costs about N minutes, so fixes
were verified in side caches (`build/probe-side{1,2,3}.tsv`) and the main pass
was left running; a failed module is never cached, so a fix that lands before a
dependent is reached heals it for free. Pass 2 over the four stale rows was 4/4.

**Decision.** 6.2.2 is the entry point; D45 stands. Next: link the compiler
proper into a binary with mhs, run it on 6.2.2's own `libraries/base` to `.hc`,
and compile that against `build/rts622`. That is where D45's "not yet shown"
items get tested.

**Overturned by:** the linked compiler failing at runtime in a way the shims
cannot absorb, or `.hc` output this RTS rejects.

## D47 — The compiler links, runs, and compiles base: 137/143 modules to .hc
*2026-09-10.* D46's next step done. `mhs` emits GHC 6.2.2's compiler proper as
one combinator program, gcc turns it into a 2.9 MB `ghc`, and that binary
compiles 137 of the 143 `.hs`/`.lhs` modules of 6.2.2's own `libraries/base`
to `.hi` + `.hc`; all 137 `.hc` files then compile to `.o` with gcc against
`build/rts622`'s headers, and every RTS symbol they reference is in
`libHSrts.a`. Work in `build/ghc622-mhs` (`FINDINGS.md`, `LOG.md`,
`build.sh`, `run-base.sh`, `build-hc.sh`).

**D45's overturn tests did not fire.** The linked compiler did not fail in a
way the shims could not absorb, and the RTS did not reject the `.hc` output.

**The five runtime gaps, and what they have in common.** Four of the five are
one thing: *MicroHs traps arithmetic where GHC wraps.*

| gap | where | fix |
|---|---|---|
| `exitWith` caught by the driver's own top-level handler (`__GLASGOW_HASKELL__=408` picks the pre-5.01 `catchAllIO`) | every clean exit became "the impossible happened" | `ExitException` in the EXCEPTION shim + `!defined(__MHS__)` on the `#if` |
| `hFileSize` absent | no interface could be read | `readBinMem` reads the file whole; it has the path |
| `WANT_OVERFLOW 1`: `+ - *` on Int raise | CSE (`hash_expr` wraps on purpose) | build against a `config.h` with `WANT_OVERFLOW 0` |
| `fromInteger` into Int8/16/32 is checked | every negative literal in an interface (`Binary Integer` writes a 0xff sign byte) | wrap by hand in `Binary.hs`, and in `Literal.lhs`'s `narrow*Lit` |
| `negate`/`abs` of `minBound` raise (`T_NEG`, not covered by WANT_OVERFLOW) | `hashExpr` | test for `minBound` first |

The second thing is space: the demand analyser exhausts the MicroHs stack and
then the heap on seven modules, because GHC's own strictness analysis is what
kept `dmdFix`'s `plusUFM_C both` chains short when GHC compiled itself.
`-O -fno-strictness` compiles them in seconds; `run-base.sh` retries with it
automatically. Three modules (`Data.Complex`, `Data.Graph`,
`System.Console.GetOpt`) blow up the same way with strictness analysis *off*,
in a pass that prints nothing before it dies, and are still open.

**One 2026-toolchain item, the same class as D31/D40:** configure's
`FPTOOLS_CHECK_HTYPE` probes have a K&R `main()`, which gcc 16 rejects, so
every `HTYPE_*` was left undefined and `Foreign.Storable` (with 96 modules
behind it) would not compile. `build/ghc622-mhs/gen-htypes.c` reruns the
probes' logic and its output is appended to our `ghc/includes/config.h`.

**Not shown yet:** a link. That needs the four `.hsc` modules of base (there is
no `hsc2hs` in the chain yet), base's `cbits`, and `libHSbase.a`. Until a
compiled-Haskell program runs, D45's "runtime correctness under compiled
Haskell" is still open -- what is new is that the *compiler* is now real
compiled-Haskell-adjacent evidence: 137 modules of GHC's own libraries went
through it without a wrong-code symptom, and the RTS accepts every object.

**Overturned by:** the produced `.hc` failing to link or to run once base is
complete.

## D48 — A compiled Haskell program runs: `putStrLn "hello"` works on 6.2.2
*2026-09-10.* `main = putStrLn "hello"`, compiled by the mhs-built GHC 6.2.2,
linked against its own `base` and RTS, **prints `hello` and exits 0**. This is
the exact point where the 4.08.2 chain died (D42: handle setup in a 64-bit
runtime that had never seen one). Work in `build/ghc622-mhs`
(`FINDINGS-link.md`, `link.sh`, `build-cbits.sh`, `build-libbase.sh`, `test/`).

```
C compiler + Hugs source -> mhs -> ghc (6.2.2) -> .hc -> gcc -> ld -> hello
```

**What runs.** Twelve programs, exit codes as expected: `return ()`; `hello`;
319 MB allocated through 1218 collections (the 32-bit `HEAP_ALLOCED` hack
held, well under 4 GB); Integer/GMP with a 9131-digit product; `Double`
show/read through `floatToDigits`; stdin, args, files, stderr, `exitWith`;
exceptions including an uncaught one (`Fail: divide by zero`, exit 1);
`forkIO`/`MVar`/`Chan`; arrays, bits, `FiniteMap`; and the seven modules that
came through our mhs-built `hsc2hs` (`System.Time`, `CPUTime`, `Directory`,
`Random`, `Text.Regex` against glibc's `regcomp`).

**What it took, beyond D47.** Less than expected. base's cbits compiled with
no errors and no patches; `hsc2hs` built from the tarball's own source with
17 lines of instance splitting; the link, reproduced by hand from
`DriverPipeline.staticLink` with the 32 `-u` symbols from
`rts/package.conf.in`, had **zero undefined symbols the first time**. None of
D41's gaps exist in 6.2.2: `__encodeFloat` is defined unconditionally and
`AutoApply.hc` is already part of the RTS.

**Two real bugs found by running code.**

1. **`-fwrapv` is mandatory** for `.hc` files. `show (minBound :: Int)`
   printed `-0`: `GHC/Show.lhs` detects `minInt` with `negateInt# n# <# 0#`,
   which gcc 16 deletes under the signed-overflow rule. GHC itself added
   `-fwrapv` in 6.8. Now in `build-hc.sh` and `link.sh`.
2. **The FastString shim could give two strings one unique.** Its `intern`
   was not re-entrant: a derived `OccName` (`$w...`, `$s...`, `$f...`) built
   while its parent was being interned collided with it. Five of base's
   interfaces were written with a collision (`GHC.List`, `GHC.Float`,
   `GHC.Real`, `Data.Array.Diff`, `Text.Html`), because `Binary`'s interface
   dictionary is keyed by the unique. The visible symptoms were the three
   "space blow-ups" of D47 (the simplifier inlining a wrapper's unfolding
   under the worker's name, for ever) and a `round (2.5::Double)` panic at
   `-O`. The generated `.hc` is correct, so every run result above stands;
   only optimising importers of a damaged `.hi` were affected. Shim fixed,
   compiler relinked, and base rebuilt from scratch beside the old objects:
   **147/147 modules, zero collisions** in a `--show-iface` scan of every
   interface, the three former "blow-ups" in 47 s, 25 s and 6 s. The
   downstream damage was real (`Foreign.C.Types` had a worker in a
   dictionary slot; `GHC.Real`'s five `Ratio` dfuns were misnamed in 16
   interfaces), which is why the full rebuild was the right call. The
   rebuilt tree is now the canonical `libraries/base` and `hcobj`
   (`build/ghc622-mhs/SWITCH-NOTE.txt`); all twelve programs relink and
   pass against it at `-O`, including the two that panicked before.

**Decision.** The 6.2.2 pivot (D45) is vindicated end to end: every rung from
a C compiler to a running Haskell program is built from source by the rung
before it, and the 64-bit runtime problems that ended the 4.08.2 chain do not
exist here. What remains is hygiene, not discovery: a clean base rebuild with
the fixed shim, folding the new edits into `phase4`, and then the next stage
of the ladder, 6.2.2 compiling itself.

**Overturned by:** nothing so far.

## D49 — Stage 2 begun: the mhs-built GHC compiles its own source; interrupted
*2026-09-10, written up 2026-09-15 from `build/ghc622-stage2/LOG.md` and
`results.tsv`.* D48's next step, a native `ghc` (6.2.2 compiled by 6.2.2 via
`.hc` and gcc, linked against `build/rts622` and the stage-1 base), was
started the same morning in `build/ghc622-stage2` and stopped when the
session that ran it ended. No decision was reached; this entry records the
state so the resume starts from facts.

**What was set up.** A pristine 6.2.2 extraction with only the generated
files added (our parsers and primop tables, a `Config.hs` stating 6.2.2,
unregisterised, no NCG, `cBooterVersion "6.2.2"`, the run1 `config.h` and
`DerivedConstants.h`); a 220-module order (the probe's 235 minus GHCi, ILX,
Java and the Makefile's non-GHCI exclusions, plus `Config`); a `package.conf`
with `rts`, `base`, `haskell98`; `libraries/haskell98` compiled by the
stage-1 compiler, 30/30 to `.o` and `libHShaskell98.a`; and a driver
(`run-compiler.sh`) with the Makefile's flags and a retry ladder
`-O` -> `-O -fno-strictness` -> `-O0`.

**Where it stopped.** 84 rows of 220: **80 OK, 4 FAIL**, 77 of the 80 at
plain `-O` and three via `-fno-strictness`; the last row written is
`InstEnv`, the next is `NameEnv`. The first 16 `.hc` files were compiled to
`.o` (`build-hc-stage2.sh`), and the compiler's two C files build with gcc
16 unpatched: 18 objects in `obj/`. Nothing was linked; `link-stage2.sh` is written and untested.

**The four failures are all "the mhs probe could not have seen this", and
all are fixed in place.** Under 6.2.2's own base rather than MicroHs's:

| module | cause | fix |
|---|---|---|
| `Ctype` | `parser/Ctype.lhs` is Latin-1; `GetImports` reads source through a text handle, which under the MicroHs runtime decodes UTF-8 and dies (`ERR: getb_utf8`) | `__MHS__` branch in `main/GetImports.hs` using `readBinaryFile` (tree edit, **not yet in the patch series, binary not relinked**); meanwhile a `\xNN`-escaped copy under `fixups/` |
| `ParsePkgConf` | our happy writes `{-# OPTIONS_GHC -w #-}`; 6.2.2 reads the prefix `OPTIONS` and rejects the flag `_GHC` | first line of the three generated parsers rewritten to `{-# OPTIONS -w #-}` |
| `Lexer`, `DriverState` | cascades of the two above | none needed |
| (all three parsers) | the happy 1.19.5 template imports `Control.Applicative` and `Control.Monad (ap)`; neither exists in 2004's base, and `%monad { P }` means nothing uses them | the two import lines deleted |

The first is a real runtime-semantics difference between the two hosts, the
same family as D47's five; the other two are our generator leaving 2020s
boilerplate in 2004 code, invisible as long as mhs was the only consumer.

**Not yet shown.** That the 220 modules compile, that they link, and that
the native compiler reproduces the stage-1 compiler's `.hc` output for base
(`compare-base.sh` and `scan-hi-stage2.sh` are written for that check).

**Decision.** None beyond D48. The resume is `FRESH=0` on the same order
(`results.tsv` is the cache), after relinking the stage-1 compiler with the
`GetImports` edit and adding that hunk to `phase4/series.conf` so
`make-patch.sh` accepts the tree again.

**Overturned by:** nothing; there is no decision here to overturn.

## D50 — RTS patch 0003: the megablock map gets a fixed base and a window
*2026-09-16, `build/rts622`.* The first few hundred runs of the native
stage-2 compiler produced one segfault, in `--show-iface` of an interface
that then passed 160 repeats. The RTS's own comment names the cause:
6.2.2's 64-bit `HEAP_ALLOCED` ("XXX: This is a HACK") keys a 4096-entry map
on the low 32 bits of an address, and with `HEAP_BASE 0` on Linux the heap
starts wherever `mmap(NULL)` puts it, so under ASLR the heap's low 32 bits
alias the executable's `.rodata`/`.data` (static closures, map entries
18-29) in about 0.6% of processes, and the GC then evacuates static closures
as heap objects. An `LD_PRELOAD` shim that pins the first `mmap`'s hint makes
it 6/6 either way (`build/rts622/alias-test/mmap-alias.c`; FINDINGS.md
section 9 has the gdb trace and the numbers).

**Decision.** Patch the RTS rather than the environment: `HEAP_BASE
0x500000000` on x86-64 and a 65536-entry map keyed on `p - HEAP_BASE` (a
64 GB window) with `getMBlocks` refusing memory outside it
(`patches/0003-mblock-map-window.patch`). This is what 6.4 did in spirit, a
fixed heap base on x86-64, without its two-level map: the window is enough
under the 8 GB `ulimit -v` every compile runs with, and the patch is 30
lines against two files rather than a storage-manager backport. Rejected:
disabling ASLR (`setarch -R`) or hoping, which move the bug to the next
machine; linking PIE-off is already the case and irrelevant since the heap,
not the executable, is what moves. Cost: a one-minute RTS rebuild and a
relink; the stage-2 compiler, Hello, 397 interfaces, `compare-base.sh` and
two stage-3-style compiles (PrelNames 3 s, DriverFlags 2 s, `.hc` line
counts equal to stage 1's) all check out on the relinked binary. The
reproducer in `build/rts622` now has three patches; `apply-fixes.pl` covers
only the first two, `patch -p1` the third.

**Overturned by:** nothing yet.

## D51 — Stage 3 and stage 4: the native compiler rebuilds itself, 218 of 220 modules byte-identical
*2026-09-16, `build/Makefile` targets `stage3`, `test3`, `stage4`,
`compare3`, `compare4`.* The native stage-2 GHC 6.2.2 compiled its own 220
modules from the pristine source in 2 min 6 s wall (stage 1 needed 7617 s of
compile time and 25 modules at `-fno-strictness`; natively every module
compiles at plain `-O`), linked as `ghc-stage3`, and compiles Hello.hs to the
same Abstract C as stage 2. `ghc-stage3` then compiled the 220 again
(stage 4, 1 min 40 s): **218 `.hc` files byte-identical to stage 3's, all
220 `.hi` identical**. The two differences are deterministic and explained
in `build/ghc622-stage2/LOG.md`: an uninitialised upper word in a `Float`
literal (`PprAbsC.floatToWord` reads a 4-byte float array back as an 8-byte
Int, a 6.2.2 64-bit defect that the RTS never sees because `PK_FLT` reads
the low word), and one SRT with two entries swapped, from Unique assignment
order, which in a pre-8.0 GHC follows evaluation order and so can differ
between a compiler built with `-fno-strictness` in 25 modules and one built
without.

**Decision.** The chain's acceptance test is now `make test3` followed by
`make stage4 compare4`, and this is the fixed point we accept: same
interfaces, same code up to the two understood leaks. The `floatToWord`
defect stays unpatched in the pristine stage-2 source, since it does not
affect the compiled programs and patching pristine source is a scope
change; it is recorded here so that a future bit-reproducibility
requirement knows where to look (a `.&. 0xffffffff`, or 6.4's
`castFloatToWord32`).

**Addendum, the same day: stage 5.** `ghc-stage4` was linked from the
stage-4 objects and compiled the 220 modules a fifth time: **stage 5 is
byte-identical to stage 4 in all 220 `.hc` files.** `ghc-stage3` and
`ghc-stage4` differ in 38 bytes, all accounted for: the 20-byte GNU build-id
note, the swapped SRT pointer pair from `CoreUtils.o` (39 bytes in the
object, with its relocations) and the one upper-word byte of `Pretty.o`'s
`1.5f` literal; 218 of 220 objects are identical. The two leaks do not
propagate: a compiler that differs only in them writes the same output. The
fixed point is therefore reached at stage 3, and the acceptance run is
`make -j4 test3 && make -j4 stage5 && make compare4 compare5`.

**Overturned by:** nothing yet.

## D52 — 6.2.2 builds itself with its own build system; the chain climbs to 6.12.3; GMP 6.2 breaks every GHC before 8.0
*2026-10-01, `nix/ghc622/inst.nix`, `nix/ghc610`, `nix/ghc612`, `nix/gmp612.nix`,
`nix/test/GmpZero.hs`.* Three things happened in one day and one bug tied them
together.

**6.2.2 by its own `configure && make`.** `nix-build -A ghc622` is now 6.2.2
built by its own build system with the chain's stage 3 as `--with-ghc`
(`nix/ghc622/inst.nix`; the stage-3 wrapper with a side `package.conf` that
was the installed 6.2.2 until now is `nix/ghc622/boot.nix`, and nothing but
inst.nix uses it). A 2026 host needs: the three `build/rts622` RTS patches,
the `gen-htypes` block appended to `mk/config.h` (D47), `-D_GNU_SOURCE` for
hsc2hs and the C bits (`struct ucred` in network's `Socket.hsc`), the private
`execvpe` declarations of `libraries/unix` and `hslibs/posix` removed (glibc
has had it since 2.11, with other types), the C flags carried by the rts
package's `extra_cc_opts` so the installed compiler passes them to gcc, a
`happy` wrapper that applies `phase4/fix-generated-parsers.sh` to what happy
1.19.5 writes (with `GHC_HAPPY_OPTS` and `SRC_HAPPY_OPTS` emptied), the
shipped generated `.hs` touched, and the make output searched for `*** [`
because fptools' loops carry on past a failing subdirectory (hslibs/posix's
cbits did fail once and `make` still exited 0). The install has ghc, ghc-pkg,
hsc2hs and every library of the tarball: base, haskell98, haskell-src,
network, parsec, QuickCheck, unix and the hslibs compatibility packages.

Checked: the 220 compiler modules compiled by this 6.2.2 (`hcChunk`, stage
"stage6") are **byte-identical to stage 4's in all 220 `.hc` and 220 `.hi`**;
the checkout's twelve test programs behave as with the boot compiler.

**Why the nine steps before it stay.** 6.2.2's build system needs a working
GHC to drive it; stage 1 is GHC's source on the MicroHs runtime, about twenty
times slower than native and dead on some modules at `-O`. From stage 3 on
the compiler is native, and from inst.nix on the build system is the
compiler's own. Every later rung is one `configure && make` derivation
(`nix/ghc66`, `nix/ghc610`, `nix/ghc612`, ...).

**The ladder.** Each release's `configure.ac` names the oldest GHC that may
build it; the jumps that keep the chain shortest are 6.2.2 → 6.6 → 6.10.4
(≥ 6.4) → 6.12.3 (≥ 6.8) → 7.4.2 (≥ 6.12) → 7.8.4 (≥ 7.4) → 8.0.2 (≥ 7.8)
→ 8.4.4 (≥ 8.0) → 8.8.4 (≥ 8.4) → 9.0.2 (≥ 8.8) → 9.4.8 (≥ 9.0, Hadrian
only) → 9.8.4 (≥ 9.4) → 9.12 (≥ 9.6). Built today: **6.10.4 by 6.6** (libffi
needed a plain `ar`; its configure made `AR` "ar q") and **6.12.3 by
6.10.4**, both unregisterised via C and both registerised: with
`GhcUnregisterised = NO`, `GhcWithNativeCodeGen = YES` and `-fasm` for the
libraries and stage 2, the unregisterised 6.10.4 compiles a stage 1 that then
generates native x86-64 code for everything else. `ghc --info` of that
6.12.3 says Unregisterised NO, NCG YES, tables next to code YES; it passes
`nix/test/T3.hs` with no diagnostics and is half the size. From 6.12 on the
chain is registerised (`registerised ? true`), which makes every later rung
several times faster to build. 6.12.3 needed its `includes/Rts.h` blocks for
`__GNUC__ > 4`, never compiled in 2010, disabled (one defines macros as
`#pragma GCC visibility`).

**The bug.** 6.6 built by the make-built 6.2.2 died compiling `GHC/Float.lhs`,
three times out of three, while the same command passed 45 times outside the
build; 7.4.2 by 6.12.3 died compiling `GHC/Show.lhs`, whichever 6.12.3 booted
it and whichever way it was built. A gdb hook inside the build (`gdbModule`
in `nix/ghc66/ghc.nix` and `nix/ghc74/default.nix`: the in-place compiler
runs under `gdb -batch -ex run -ex bt` for the one compile) gave the same
picture twice: SIGSEGV in `evacuate`, from `scavenge_stack` (6.6) or
`scavenge_block` (7.4), on an address in the mmap region, and `info symbol`
named it: **`table.0+152`, sixteen bytes before libgmp's `dummy_limb`**.
GMP 6.2 (2020) made `mpz_init` lazy: a zero-valued result that an mpz
function returns early (`mpz_mul` by zero, `mpz_tdiv_q` with |a| < |b|, ...)
keeps `_mp_d` at a static dummy limb instead of memory the GHC runtime
allocated in the Haskell heap. Every GHC before 8.0 (6.2.2's `J#` in the RTS,
integer-gmp 0.x's Cmm wrappers) takes `_mp_d - sizeof(StgArrWords)` as the
`ByteArray#` closure, so the collector evacuates a pointer into libgmp's
data segment and dies when the word there is not an info pointer. Whether
it dies depends on what that word is and on which zeros are live at a
collection, hence the maddening reproducibility. `nix/test/GmpZero.hs`
makes 2.4 million such zeros live across collections: a program compiled by
the make-built 6.2.2 segfaults with GMP 6.3 and prints `(2400000,0)` with GMP
6.1.2 substituted by `LD_LIBRARY_PATH` — the same binary. The hand chain's
stage-1 base, with `-fno-strictness` on nine modules, had merely shifted the
allocation pattern enough to pass; the nine flags I had copied into inst.nix
on that theory were a red herring and are gone.

**Decision.** `nix/gmp612.nix` builds GMP 6.1.2 (the last before the lazy
`mpz_init`; `--disable-assembly`, `-std=gnu11` for gcc 15's C23 default, no
`-no-pie` on a shared library), and every rung before 8.0 — stage 2's link,
stages 3-5, boot, inst, happy 1.16, alex 2.1.0, 6.6, 6.10.4, 6.12.3, 7.4.2,
7.8.4 — takes it instead of the host's GMP. 8.0's integer-gmp works on limbs
and is fine with any GMP. The chain is rebuilt from the stage-2 link; the
`.hc` of stages 2-5 do not depend on GMP, so the fixed point must come out
unchanged. Rejected: patching the RTS and integer-gmp to copy a result whose
`_mp_d` is not heap-allocated (two code bases, and the distros' answer to
this bug was the GMP version too); using GHC's in-tree GMP (4.1 in 6.2.2,
built with gcc 15, a port of its own). A caveat for anyone using these
compilers outside Nix: a program they compile binds to whatever
`libgmp.so.10` the loader finds unless the GMP 6.1.2 directory is on its
path; inside Nix the cc wrapper's rpath takes care of it.

**Addendum, the same evening.** On GMP 6.1.2 the chain rebuilt without
incident: 6.2.2 by make, 6.6, 6.10.4, 6.12.3 (registerised) and then
**7.4.2** (registerised, NCG, tables next to code, 215 MB), every one
passing its install check with `GmpZero` included; 7.4.2 compiles and runs
`GmpZero` outside the build too. The fixed point is unchanged and stage 4's
440 `.hc`/`.hi` are byte-identical to before the GMP change. **7.8.4** by
7.4.2 followed (registerised, static, `DYNAMIC_* = NO`, GMP 6.1.2, 270 MB,
install check passed), the last rung that needs GMP 6.1.2.

**Overturned by:** nothing yet.
