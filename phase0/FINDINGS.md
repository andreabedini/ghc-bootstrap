# Phase 0 findings — verifying the Hugs -> MicroHs seed

Run 2026-09-02, Fedora 44, GCC 16.2.1, x86_64.
Goal: confirm the claim that MicroHs can be bootstrapped from **C compiler + Hugs
source only**, with no pre-generated combinator file. See `../BOOTSTRAP-ANALYSIS.md`.

## Result: the seed works. It needed one Hugs feature and a shim patch.

**`C compiler + Hugs source -> a working MicroHs`, with no pre-generated
combinator file — verified, and cross-checked against MicroHs's shipped seed.**
Reproduce with `./bootstrap-seed.sh`.

| Step | Status |
|---|---|
| Build Hugs 98 plus (Sep 2006) on a 2026 toolchain | **works** (3 fixes, see `build-hugs.sh`) |
| `runhugs` runs real Haskell 98 (incl. `Data.Map`, FFI-backed IO) | **works** |
| MicroHs `hugs/` shim typechecks under Hugs | **works after a 1-line fix** (`patches/0001`) |
| MicroHs compiler source parses under Hugs | **fails — pattern guards** |
| *(then)* pattern guards implemented in Hugs | **works** (`patches/0002`) |
| MicroHs compiler source parses under patched Hugs | **works** |
| MicroHs typechecks under patched Hugs | **works** (`patches/0001`, 12 one-line gaps) |
| MicroHs *runs* under Hugs and emits C for itself | **works** (`generated/hmhs.c`, 2,063,036 bytes) |
| that C compiles to a native `mhs` | **works** (`bin/hmhs`, 1,063,976 bytes) |
| fixpoint: gen2 == gen3 | **works**, byte identical |
| gen2 == output of the shipped-seed compiler | **works**, byte identical |

## 1. Hugs builds fine on a modern toolchain

Three fixes, all mechanical, all captured in `build-hugs.sh`:

1. GCC >= 14 made `implicit-int` / `implicit-function-declaration` /
   `int-conversion` hard errors. Every 2006-era autoconf probe fails.
   `-fpermissive` restores them to warnings.
2. The loadable-library probe runs `${CC} -shared conftest_dl.c ...` and does
   **not** interpolate `$CFLAGS` (`configure:15502`, `:15667`). The permissive
   flags must therefore go in `CC`, not `CFLAGS`. Otherwise every probe fails
   silently, Hugs is configured with no shared-object flags, and this surfaces
   only much later as `undefined reference to 'main'` when linking each FFI stub.
3. `libraries/tools/make_bootlib` configures `packages/base` in a subshell that
   only inherits the environment, so `CC`/`CFLAGS` must be exported for `make`
   too. Otherwise the `HTYPE_*` probes fail and you get
   `Undefined type constructor "HTYPE_INT"` in `Foreign/Storable.hs`.
   (It also hardcodes `/tmp`, which only matters under a sandbox.)

With those, `make` completes with **zero errors** and the installed `runhugs`
runs ordinary Haskell 98 correctly.

## 2. MicroHs's Hugs path has bit-rotted

`make generated/hmhs.c` (Makefile:408-410) runs the MicroHs compiler *interpreted
under Hugs* to emit C for itself. On master (`1474221`) it fails twice:

- `hugs/MHSPrelude.hs:128` — the shim annotates `try` as
  `IO (Either IOError Handle)`, but Hugs's `Control.Exception.try` returns
  `IO (Either Exception Handle)`. One-line fix in `patches/0001`.
- `src/MicroHs/Expr.hs:535` — **pattern guards**:
  `loop ts (EVar i) | Just n <- getTupleConstr i, length ts == n = Just ts`

There is no CI covering the Hugs path upstream (nothing matching `hugs` in
`.github/workflows/` or `appveyor.yml`), which is consistent with it having
rotted unnoticed.

## 3. The blocker: Hugs has no pattern guards

Verified independently of MicroHs — this minimal program fails in both modes
(`-98` *enables* extensions in Hugs; it does not help):

```haskell
f xs | (y:_) <- xs, y > 0 = Just y
     | otherwise          = Nothing
```
```
ERROR "PG.hs":3 - Syntax error in declaration (unexpected `<-')
```

This is exactly the "multiple/deconstructing guards" limitation raised in the
Discourse thread, now confirmed empirically rather than by report.

`feature-scan.py` counts roughly **200 pattern-guard sites** across MicroHs
`src/` + `lib/` (the count is a heuristic upper bound — it over-reports where a
list comprehension spans lines). *(Phase 1 tightened the scanner: comprehensions
were most of that number, and the figure is now 64, a lower bound. The conclusion
is unchanged — Hugs needed the feature either way. See
[`../phase1/FINDINGS.md`](../phase1/FINDINGS.md) §0.)* Concentrated in `src/MicroHs/TypeCheck.hs` (~73).

## What this changes about the plan

`BOOTSTRAP-ANALYSIS.md` argued the seed problem was solved because MicroHs has a
Hugs path. That is **too strong**: the path exists and is 95% there, but it does
not run today. The corrected claim is that the seed is *one contained Hugs
feature away*, not that it works.

## 4. Pattern guards, implemented (`patches/0002-hugs-pattern-guards.patch`)

Done, in `parser.y` alone — 292 diff lines, no other file touched.

**Approach.** Every phase that walks a `GUARDED` node (static.c, type.c,
compiler.c, machine.c, output.c — 13 sites) assumes a guard's test is a single
expression. Rather than teach all of them about qualifier lists, the qualifiers
are desugared at parse time into constructs Hugs already has.

The test and the body of a guarded rhs are two *separate* expressions, so
nothing typed inside one can constrain the other (that cost the first version of
this patch its type completeness, §5). The qualifiers are therefore matched
**once**, in a binding lifted into the `where` part that already wraps the whole
guard chain; the guard then only asks that binding whether it matched, and the
body only asks it for its value:

    | q1, ..., qk = rhs
    ==>
    | case v of { Just _ -> True; _ -> False } = case v of { Just w -> w }
    where v = SEL(q1..qk, rhs)                             -- v, w fresh

    SEL([],          r) = Just r
    SEL(b : qs,      r) = if b then SEL(qs,r) else Nothing
    SEL(let ds : qs, r) = let ds in SEL(qs,r)
    SEL(p <- e : qs, r) = case e of { p -> SEL(qs,r); _ -> Nothing }

Everything the qualifiers bind, and the body that uses it, now live inside one
expression, so type information flows between them as it does in the source
program. Each qualifier and the body also appear once rather than twice, so a
scrutinee is *matched* once as well: `v` is a shared thunk and is already in
whnf by the time the body looks at it.

`mkGuard` returns `pair(bindings, guard)`; `pgGuarded` collects the bindings of
a whole guard chain and `pgWhere` merges them into the where part, producing
exactly the `LETREC(decls, GUARDED(...))` that a hand-written `where` produces
— no new tree shape reaches the rest of the compiler. Fresh names come from
`inventText`, whose texts sit outside the identifier table (`inventedText`) and
cannot collide with source names. The lifted binding is monomorphic — the
monomorphism restriction applies to it, and that is what is wanted here: `v`
must not be generalised away from the guard that uses it — and it is in scope
over the left-hand-side arguments and the other `where` bindings, exactly like
anything else written there.

The grammar reuses the existing `FROMQUAL`/`BOOLQUAL`/`QWHERE` qualifier nodes.
It uses `exp0` rather than `exp`, matching the boolean guards it replaces —
a top-level `::` would be ambiguous with the `->` closing a case alternative.

**Three things that are easy to get wrong here, and did bite:**

1. *Tree sharing.* `bindPat` and `depExpr` in static.c rewrite trees **in
   place**. Using the same pattern cells at two binding sites binds them twice;
   `Just y` happened to survive it, `(y:_)` looped forever. Matching each
   qualifier once removes the hazard at its root; where the desugaring still
   needs a name in two places (`v`, `w`) it builds a separate `mkVar` cell per
   occurrence instead of sharing one.
2. *Garbage collection.* `pair()` collects when the free list runs dry and
   protects only its own two arguments, so a subtree held in a C local does not
   survive the next allocation. Intermediates go on the Hugs stack (a GC root,
   storage.c:3670) with balanced push/drop so the parser's own use of `sp` via
   `gcShadow` stays intact. The same rule shapes the expressions themselves:
   at most one freshly allocated argument per constructor call, so that every
   new cell is an argument of the next allocation rather than sitting in a C
   local across it. **The incoming qualifier list needs the same care**, which
   is easy to miss: the grammar hands it over as `rev($2)` and `rev` is
   destructive, so the parser's own shadow of `$2` is left pointing at what is
   now the *last* spine cell and protects none of the rest — the wrappers, the
   patterns and the scrutinees included. Only `$3` and `$4`, the line and the
   rhs, stay shadowed (see `gcShadow`), so `mkGuard` pushes the list itself
   before it allocates anything.
3. *`Just` and `Nothing` do not exist yet while the Prelude is parsed.* They
   are `Name`s linked by `linkPreludeCM`, which runs from `checkDefns` — after
   the Prelude has been through the parser. A pattern guard *in the Prelude
   itself* would build `ap(NIL,...)` and blow up much later inside `depExpr`,
   so `mkGuard` rejects that case up front with a real message. A guard that
   binds nothing takes the early return and never touches those names, which is
   what keeps ordinary guards working while the Prelude is being parsed. This
   is a new dependency: pristine `parser.y` references only `nameFrom*`,
   `nameNil`, `nameUnit`, `nameFlip` and `nameNoRec`, all of which exist before
   anything is parsed.

**No-regression by construction:** for a guard that binds nothing, `mkGuard`
returns precisely the tree the old grammar built and lifts no binding, so
ordinary guards are bit-identical and cost nothing extra. Guard forms that are
not Haskell 98 are still rejected in `haskell98` mode, now through the same
`h98DoesntSupport` the rest of the parser uses — "Haskell 98 does not support
pattern guards", or "… guards with more than one qualifier", which are two
different violations and used to share one message that blamed the lookahead
token (`Syntax error in guard (pattern guards need -98) (unexpected `|')`) and
reported the wrong line.

### Evidence

- **Zero new grammar conflicts**: bison reports 6 shift/reduce before and after
  (the file's header says "expect 16"; the real number today is 6).
- **The GC protection is verified by experiment, not by argument.** A throwaway
  build with a forced `garbageCollect()` at `guardSel`'s base case and `consGC`
  cleared (so the conservative C-stack scan, which otherwise masks the whole
  question, is off) runs a four-qualifier guard correctly with the push in
  place, and dies with `INTERNAL ERROR: depExpr` with it removed and nothing
  else changed. Without that instrumentation the bug is invisible: `consGC` is
  set during parsing, and `initInterpreter` restores it before every command.
- **The Prelude case gives a diagnostic, not an internal error**: a pattern
  guard appended to a copy of `Hugs/Prelude.hs` reports
  `Pattern guards cannot be used before the Prelude is loaded` at the right
  file and line, while an ordinary guard in the same place still loads.
- **`tests/PatternGuards.hs`** — 23 cases, all correct: generators; generator
  plus boolean sharing a variable; **fall-through to the next equation**;
  bindings not escaping to a later guard; `let` qualifiers; several generators
  where a later one depends on an earlier; case alternatives with `where`;
  nested patterns and wildcards; shadowing; laziness; instance methods; plain
  guards unchanged; **type flowing from the body into the guard** (cases 13-15,
  the §5 bug); a guard beside a `where` clause it reads; a guarded rhs nested in
  the `where` part of another guarded rhs; a guard inside a case alternative
  inside another guard's qualifier; **the scrutinee matched exactly once**
  (counted through an `IORef`); boolean-only multi-qualifier guards; guards on a
  pattern binding; guards in a local `let`; and a `where` part holding
  multi-equation functions, which the lifted binding is spliced in beside.
- **The whole Hugs `base` bootlib recompiles** under the patched parser with
  zero errors (117 modules), and **all 21 `demos/` load clean**. (The tarball's
  `make check` target references a `tests/` directory that is not shipped, so
  there is no upstream suite to run.)
- **MicroHs, end to end**: with `Interactive.hs` back to its upstream form (the
  §5 workaround dropped from `patches/0001`), all 250 modules typecheck under
  the patched Hugs, `generated/hmhs.c` comes out **byte-identical** to the run
  in §8, and the compiler built from it still emits the same `mhs2.c`
  (`09f85536…`). The desugaring change is invisible downstream.

## 5. Type completeness (a limit that was found by using it, then fixed)

The first version of this patch desugared a guard by *duplicating* the
qualifiers — `TEST(qs)` for the guard and `BODY(qs,rhs)` for the body. Those are
two separate expressions in the guard pair, so type information that flows from
the body into the guard was lost. `Interactive.hs` had:

```haskell
Just line <- stripSuffix "," sline >>= readMaybe -> Just (file, line)
```

In BODY, `line` is used at `Int`. In TEST, it was bound and discarded, so
`readMaybe`'s `Read a` had nothing to resolve it and Hugs rejected the binding:

```
ERROR - Cannot justify constraints in explicitly typed binding
*** Constraints   : Read a
```

A program well typed in Haskell 2010 was therefore rejected. It bit once in 250
modules and was worked around with a type annotation.

Duplicating more cannot fix this; the qualifiers have to be matched **once**, in
a place both the guard and the body can see. That is what the desugaring in §4
now does, so the annotation is gone from `patches/0001` and `Interactive.hs` is
back to its upstream form. `tests/PatternGuards.hs` cases 13-15 pin the
behaviour down, including the same shape behind two dependent generators and
behind a `let` qualifier.

The fix removed the duplicate evaluation as well: a guard's scrutinee used to be
evaluated twice (once to decide the guard, once to rebind its variables over the
body), and is now evaluated once.


## 6. Hugs's Int is 32-bit; MicroHs assumes 64-bit

`prelude.h:695` has `typedef int Int` and `MAXPOSINT 0x7fffffff`. MicroHs assumes
a 64-bit `Int`. The first casualty was `getTimeMilli`, where epoch milliseconds
(~1.7e12) overflow the `Integer -> Int` conversion and `bignums.c:346` throws
`ArithException Overflow` — surfacing as a bare `Program error: arithmetic
overflow` right as the first module is compiled.

Worked around by reducing the clock modulo 1e9 (MicroHs only takes differences
of these, for timing reports). **This is a class of bug, not one bug**: any
MicroHs code relying on 64-bit `Int` will misbehave under Hugs, silently or
otherwise. Making Hugs's `Int` 64-bit is invasive (it is the cell payload
width); the practical answer is to fix instances as they appear.

## 7. The shim grind, and how far it got

Each blocker was a one-line gap in MicroHs's own `hugs/` tree
(`patches/0001-microhs-hugs-shim.patch`, 5 files):

| Error | Fix |
|---|---|
| `Undefined type constructor "Int64"` | `MHSPrelude` imported `Data.Int` but never re-exported it |
| `NFData ByteString` missing | add the instance |
| `Undefined variable "makeVersion"` | new `hugs/Data/Version.hs` shim (`Version.hs` imports `Data.Version` directly) |
| `Undefined variable "readSerializedBS"` | the hugs `Serialize` shim omitted two of the names the ghc one stubs |
| `Undefined variable "getExecutablePath"` | base 4.6+; callers already wrap it in a `catch`, so failing is the right shim |
| `Ambiguous variable occurrence "catch"` | hide `Prelude.catch` so `Control.Exception.catch` wins |
| `Unknown entity "readMaybe"` | new `hugs/Text/Read.hs` shim |
| `Ambiguous variable occurrence "makeVersion"` | `MHSPrelude` defined it too — dropped, `Data.Version` is now the single source |
| `Undefined variable "setEnv"` | base 4.7+; no-op shim |
| `cannot find config file: mhs.conf` | `make mhs.conf` |
| `Control stack overflow` | two independent limits, see below (`patches/0003`) |
| `Program error: arithmetic overflow` | §6 |

### The two stack limits

`Control stack overflow` comes from **two unrelated places**, which cost a
couple of rebuilds to separate:

- `NUM_STACK` (`prelude.h:755`, 160000 in the "large" build) sizes `cellStack`,
  the interpreter's own stack. It is heap-allocated via `TABALLOC`, so raising
  it costs address space, not a static array.
- `MAX_EVAL_DEPTH` (`prelude.h:774`, **16384**) limits nested `eval()` calls at
  `machine.c:1319`. `eval` recurses in **C**, so this is really a guard on the
  process's C stack — and raising it also needs `ulimit -s` raised.

Raising `NUM_STACK` alone from 160000 to 40000000 (250x) changed nothing,
because `MAX_EVAL_DEPTH` was the binding constraint the whole time. That is the
sort of thing worth knowing before spending rebuilds on the wrong knob.

**Result: every MicroHs module typechecks and loads under Hugs, and MicroHs then
runs and compiles 250 modules of its own source** — the whole compiler, plus
`Text.Printf`, `System.Compress`, `MicroHs.Interactive`, `MicroHs.Main`. The
failure moved from *"Hugs cannot parse this language"* to *"the interpreter runs
out of control stack near the end of a self-compile"*, which is a different
kind of problem entirely.

## 8. The seed, verified end to end

```
                                        sha256 of the emitted C
Hugs (C source only) runs MicroHs  -> hmhs.c   dcc47316...  gen1
  cc hmhs.c                        -> bin/hmhs
  bin/hmhs compiles MicroHs        -> mhs2.c   09f85536...  gen2
  cc mhs2.c; it compiles MicroHs   -> mhs3.c   09f85536...  gen3  == gen2
MicroHs's shipped generated/mhs.c
  cc it, it compiles MicroHs       -> mhsS.c   09f85536...        == gen2
```

Two results, and they are different claims:

1. **Fixpoint.** gen2 == gen3, byte for byte. The compiler obtained from the
   seed reproduces itself exactly, so it is a genuine self-hosting compiler and
   not an accident of the first generation.
2. **Diverse double compilation.** The compiler derived from *Hugs source only*
   and the compiler derived from *MicroHs's shipped pre-generated C* emit
   byte-identical output. That is independent evidence that the shipped seed is
   honest — it is what its source says it is — and it removes the pre-generated
   combinator file from the trusted base.

`bin/hmhs` was also checked on real work: it compiles and runs `Example.hs`,
bignums included (40! is correct).

### One loose end: gen1 differs from gen2

The C emitted *while running under Hugs* differs from the native runs in 18483
of 2063036 bytes (~0.9%), in the region encoding the FFI table. It is benign —
`bin/hmhs`, built from that very output, then produces the canonical result — so
the difference is confined to generation 1 and does not propagate.

The likely cause is §6: under Hugs, MicroHs's `Int` is 32-bit, which can change
label numbering or table ordering. Worth pinning down before anyone leans on
this chain for a reproducibility argument, because a clean story would have gen1
match too. It does not affect the two results above, both of which are exact.

## Reproducing

```sh
phase0/bootstrap-seed.sh              # the whole chain, ending in two cmp checks
```

or step by step:

```sh
cd phase0
./build-hugs.sh                       # applies patches/0002 and 0003, needs bison
export PATH=$PWD/prefix/bin:$PATH
runhugs -98 tests/PatternGuards.hs    # pattern-guard test suite
cd ../MicroHs
git apply ../phase0/patches/0001-microhs-hugs-shim.patch
make mhs.conf
ulimit -s unlimited
make generated/hmhs.c bin/hmhs
```

Logs from this run: `configure*.log`, `build*.log`, `hmhs.log`.
