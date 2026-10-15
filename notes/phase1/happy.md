# Can `mhs` compile happy?

Run 2026-09-02, Fedora 44, x86_64, using `MicroHs/bin/mhs` from Phase 0.
Context: [`FINDINGS.md`](FINDINGS.md) §4 found that GHC 4.08.2 ships `Parser.y`
and `ParseIface.y` with no generated `.hs`, so **happy is a hard build
dependency** of the chosen target — and happy is itself a Haskell program, so it
is a nested instance of the bootstrap problem. This file answers whether `mhs`
can take it on.

Subject: `happy-1.19.12` from Hackage, the last of the 1.x line.

## Result

**The language is not the problem. The libraries are, and they are small.**

Every hand-written module in happy either compiles under `mhs` or fails only for
want of a library module. The only *language* rejections in the whole package are
in the two files that are not hand-written — and those turn out to be unusable
for a different and more interesting reason (§2).

## 1. happy is small and old-fashioned, which is what we want

`../notes/phase0/feature-scan.py` and `import-inventory.py` over `happy-1.19.12/src`:

```
16 source modules, 3,747 code lines     (plus 2 generated files, 2,897 lines)
pattern-guard      0        gadt-syntax   0        type-family   0
lambda-case        0        bang-pattern  0        rec-do        0
cpp               19        forall        3
mutual recursion:  0 {-# SOURCE #-} imports
```

Zero pattern guards, zero mutually recursive modules, 19 CPP directives. For
comparison, GHC 4.08.2's compiler is 77,734 lines with 52 `{-# SOURCE #-}`
imports. happy is roughly **1/20th the size of the thing it exists to unblock**.

`-XCPP` works: `mhs` shells out to `cpphs`, and MicroHs ships one
(`make bin/cpphs`, built from `generated/cpphs.c`). That also exercises the cpphs
step that [`FINDINGS.md`](FINDINGS.md) listed as unverified — it runs.

## 2. The shipped generated parser is unusable, and that is clarifying

happy's tarball does not contain its grammars at all. `src/Parser.ly` and
`src/AttrGrammarParser.ly` exist only in the repository; the tarball ships the
*generated* `Parser.hs` and `AttrGrammarParser.hs` instead:

```
src/Parser.ly              148 lines   ->  src/Parser.hs             1,669 lines
src/AttrGrammarParser.ly     ?         ->  src/AttrGrammarParser.hs  1,228 lines
```

Those two are the only files `mhs` rejects on grammar:

```
./Parser.hs:170:1: found: ;
  expected: - LQIdent ( UQIdent [ QualString literal _primitive @ (# \ case let if ...
```

The cause is on line 167:

```haskell
happyExpList = HappyA# "\x00\x00\x00\x00\x80\x00..."#
```

an unboxed `Addr#` string literal. The file was generated with happy's **GHC
backend**: `{-# OPTIONS -XMagicHash -XBangPatterns ... #-}`,
`import qualified GHC.Exts as Happy_GHC_Exts`, and 53 uses of `unsafeCoerce#` /
`HappyA#` / `indexCharOffAddr#`. Its only `#else` covers `HappyAny`; there is no
portable branch for any of that.

**So the "just trust the shipped blob" shortcut is not merely impure here — it
does not work.** The artifact is GHC-specific by construction, and no MicroHs
shim can make `unsafeCoerce#` mean anything.

That forces the honest route rather than merely recommending it:

1. Take the real grammars from the repository (148 lines for `Parser.ly`).
2. Regenerate with happy's **portable** template — `data/HappyTemplate`, not
   `HappyTemplate-arrays-ghc`. That emits plain Haskell tables, no `MagicHash`.
3. Compile the result with `mhs` plus the shims below.
4. Use the resulting happy to regenerate its own portable parser, and check the
   fixpoint.

Step 2 still needs *a* happy, so the circularity is real. But it is now a
148-line grammar and a template choice, not a 1,669-line opaque table you must
either trust or discard.

A note on how strong that fixpoint would be: it is **weaker than what Phase 0
achieved for MicroHs**. Phase 0 got diverse double compilation — the Hugs-derived
compiler and the shipped-seed-derived compiler emitting byte-identical output, two
genuinely independent producers. A happy self-fixpoint proves self-consistency
only; it does not detect a Thompson attack. Getting DDC here needs a second,
independent producer of that parser. At 148 lines of LALR grammar, that is
cheap — which is exactly the argument for paying this cost at happy's scale
rather than GHC's.

## 3. The shims

`import-inventory.py` put eleven modules in happy's gap bucket. What they need
turned out to be tiny — the whole of happy uses ten `Data.Set` functions, three
`Data.Map` functions, and no mtl class machinery at all (`tell` appears only in a
plain `Writer`, and `lift` is written explicitly where the stack is
`ExceptT String (Writer (Set Inst))`).

They live in [`shims/`](../../common/shims) (now `common/shims`), which is the beginning of Phase 2's
`ghc-on-mhs` package rather than throwaway scaffolding:

| shim | over | note |
|---|---|---|
| `Data.Array` | `Mhs.Array` | two-line alias; MicroHs has the module under another name |
| `Data.Array.IArray`, `.Unboxed` | `Mhs.Array` | `type UArray = Array` — boxed, same API |
| `Data.Array.MArray`, `.ST` | `Mhs.MutArr` | real `MutSTArr`, so `readArray`/`writeArray` are O(1) |
| `Data.Set`, `Data.IntSet` | sorted list | O(n) insert; fine at happy's scale, and auditable |
| `Data.Map` | sorted assoc list | same |
| `Control.Monad.Reader` | — | `ReaderT`, `ask`/`asks`/`local` |
| `Control.Monad.Writer` | — | `Writer`, `tell`, `runWriter` |
| `Control.Monad.Except` | — | `ExceptT`, `throwError`, `catchError` |
| `Control.Monad.Trans` | — | `MonadTrans(lift)` defined **once** and re-exported by the three above, so a module importing two of them sees one `lift`, not an ambiguous occurrence |
| `Paths_happy` | — | happy-specific; in [`happy-shim/`](../../happy/shim) (now `happy/shim`), not `shims/` |

The array shims are the interesting ones. MicroHs's `Mhs.MutArr` is a genuine
mutable array (`primArrAlloc`/`primArrRead`/`primArrWrite`), so
`Data.Array.MArray` over it is a real implementation, not a simulation with a
list behind it — which matters, because happy's table builder does
`newArray (0, mAX_TABLE_SIZE) 0` and then writes into it. What MicroHs lacks is
only the `MArray`/`IArray` *class* interface, and no caller in happy needs the
overloading.

## 4. Result of the per-module run

With `shims/` on the include path, `mhs -c -fno-code -XCPP` over
happy-1.19.12's eighteen modules:

```
shims          Data.Set  Data.Map  Data.IntSet  Control.Monad.{Reader,Writer,Except}
               Data.Array.{MArray,ST,IArray,Unboxed}                        all OK

happy          AbsSyn      OK      Lexer        OK      NameSet    OK
               AttrGrammar OK      Target       OK      PrettyGrammar OK
               GenUtils    OK      ParamRules   OK

               First, Grammar, Info, LALR, Main, ProduceCode, ProduceGLRCode
                 -> all fail on ./AttrGrammarParser.hs:71 (the generated file)
               Parser, AttrGrammarParser
                 -> fail on the unboxed Addr# string literal
```

**Every module that does not transitively import a generated parser compiles.**
Every failure — all ten of them — is the same two generated files, reached
through the import graph. Nothing in happy's hand-written source defeats `mhs`:
not the monad transformers, not the mutable-array table builder, not the
literate modules, not CPP.

That is the answer to the question in the title. `mhs` can compile happy; it
cannot compile the artifact that happy's tarball ships *instead of* its parser.

## 5. What follows

The route is therefore forced, and is recorded as
[D5–D7 in the decision log](../../DECISIONS.md):

- Bootstrap **happy 1.19.5**, whose tarball is genuine source — both `.ly`
  grammars, no generated `.hs`, and the portable `templates/GenericTemplate.hs`.
- Use the machine's GHC once, outside the trusted base, to turn `Parser.ly` into
  a portable `Parser.hs`.
- Compile that with `mhs` + `shims/` to get `happy-mhs`.
- Discharge the GHC dependency: `happy-mhs` must regenerate the same
  `Parser.hs` from `Parser.ly`, byte for byte.

## Reproducing

```sh
common/shims/                         # the Data.Array / containers / mtl shims
happy/shim/Paths_happy.hs      # happy-specific

MicroHs/bin/mhs -C -c -fno-code -XCPP \
  -icommon/shims -ihappy/shim -ibuild/happy-1.19.12/src <Module>
```

`mhs` needs `cpphs` on `PATH` for `-XCPP`; build it with `make bin/cpphs` in
`MicroHs/`. Expect ~25 s per module even with the `-C` cache warm.
