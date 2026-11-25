# Decisions — bootstrapping GHC

The decisions that stand: what the chain does, why, and, where it is known,
what would change it. This file describes the current state only. When a
decision stops holding it is removed, and the commit that removes it says why;
how each entry was reached is in `git log -p -- DECISIONS.md`. Numbers are
stable identifiers and are never reused, so there are gaps: a number cited
elsewhere that is missing here belongs to a decision that no longer stands
(`git log -S 'D40 —' -- DECISIONS.md` finds it).

---

## D1 — The seed is a C compiler and Hugs's source, not MicroHs's shipped C

MicroHs is compiled from its source by Hugs, which a C compiler builds from
source. `nix-build -A mhs` sets the shipped `generated/mhs.c` aside, has Hugs
run the compiler on its own source, builds `bin/mhs` from the output, and
checks two things: generation 3 equals generation 2, and generation 2 written
with `-z` (the compressed form a release ships) equals the shipped
`generated/mhs.c` byte for byte. So the shipped seed is exactly what the
Hugs-derived compiler emits from the source: diverse double compilation of
MicroHs. Details: [`mhs/README.md`](mhs/README.md); the version is D58.

---

## D3 — Shims supply what MicroHs's libraries lack, written against its own machinery

Where a program needs a library MicroHs does not have, or has with other
behaviour, a shim module on the `-i` path supplies it: `common/shims/`
(mtl, containers and the like, used by happy, alex and GHC 6.2.2's stage 1)
and `ghc622/shims*/` (the GHC-internal and Haskell 98 modules of 2004). They
are built on MicroHs's real primitives (`Mhs.Array`, `Mhs.MutArr`), not on
simulations of GHC's.

A shim follows the library it stands in for wherever a caller can tell the
difference. `Data.Map.fromList` keeps the last of duplicate keys, as
containers does, because alex 2.1.0's `mk_int_dfa` depends on it.
`Data.Map` is a weight-balanced tree, because GHC's `FastString` interning
(D20) does one lookup per identifier.

---

## D4 — happy is a required sub-bootstrap

GHC's parsers are happy grammars. Using the generated parsers a GHC tarball
ships would put a large generated artefact inside GHC itself, so the chain
builds happy with mhs and regenerates them: 6.2.2's with that happy (D46),
every later version's with a happy the chain built (D55). The one generated
input this leaves, happy's seed for its own two parsers (D7), is far smaller
than GHC's parsers.

---

## D5 — No shipped happy parser can be used; happy's grammar must be regenerated

Every happy tarball on Hackage from 1.15 to 1.19.12:

| version | ships `Parser.ly` | ships generated `Parser.hs` | portable? |
|---|---|---|---|
| 1.15 | no | no | — |
| 1.16 | yes | yes | **no** — unguarded `HappyA# "…"#`, `Addr#`, `narrow16Int#` |
| 1.17 – 1.19.4 | yes | no | — |
| 1.19.5 | yes | under `dist/`, by 1.19.4 with `-agc` | **no** — `HappyA#`, `Addr#` |
| 1.19.12 | no | yes | **no** — `-XMagicHash`, 53 × `unsafeCoerce#`/`HappyA#` |

mhs rejects the generated parsers on the same construct, an unboxed `Addr#`
string literal (`HappyA# "\x00…"#`), which is lexical and cannot be shimmed.

---

## D6 — The bootstrapped happy is 1.19.5

Its tarball has both `.ly` grammars and the portable
`templates/GenericTemplate.hs`. The parsers it ships under `dist/` are happy
1.19.4's `-agc` output, which mhs cannot lex, and nothing in the chain
builds from them. 1.19.12 would need the grammars
fetched from the repository; 1.16 and earlier ship a generated parser that
cannot be used (D5).

---

## D7 — happy's seed is a GHC-built happy's output, discharged twice

`happy/happy-seed/` holds happy 1.19.5's `Parser.hs` and
`AttrGrammarParser.hs`. Generation 1 of them was written by a happy built
with GHC 9.14, used once as a generator, deliberately; D55 lists the other
generated inputs and how each is handled. The seed
is generation 2, and it is discharged two ways:

1. **Fixed point** (D14). The happy that mhs builds from the seed regenerates
   both files byte for byte (`happy/happy.nix`, check phase).
2. **Diverse double compilation** (D56). happy 1.15, from the parser happy
   1.14 wrote, leads to the same seed byte for byte.

A fixed point alone shows only self-consistency; the second, independent
producer is what detects a compromise carried in the seed.

---

## D8 — The hand-run chain keeps its artefacts in `build/`

`build/Makefile` and its scripts keep sources, extractions and intermediate
compilers in the project rather than in a temporary directory, which loses
them between sessions. The Nix chain keeps everything in the store.

---

## D9 — happy's generator is happy 1.19.x, not happy 2.x

happy 2.x always writes `--ghc` code (`MagicHash`, `Addr#` literals), which
mhs cannot lex (D5). happy 1.19.x run with no flags writes the portable
`Data.Array` template. This changes if happy 2.x regains a portable backend
or mhs learns unboxed string literals.

---

## D11 — Tarballs stay pristine; changes are side directories or numbered patches

Every source is used as released. Shims (D3), boot files (D22a) and
generated files sit beside the tree and reach the compiler through `-i`
paths. Source changes are numbered patch series against the unmodified
tarball: `hugs/patches/`, `ghc622/patches/` (generated by
`ghc622/make-patch.sh` from `ghc622/series.conf`), `ghc622/rts/patches/`,
and the per-version patches from 6.6 on. At any point what was changed can be
diffed against what upstream shipped.

---

## D12 — Where MicroHs's `base` differs, a shim reproduces the old behaviour

Prefer a shim that reproduces the behaviour a package expects over a patch
that adapts the package to modern `base`. The shim stands in for a specific
historical library, and a patch would make the package's source disagree with
its tarball for a reason that has nothing to do with the package.

For example, happy's `happyError = fail …` in
`ReaderT (String,Int) (Either String)`. Pre-`MonadFail` mtl gave `Either e`
`fail = Left . strMsg`; MicroHs follows modern `base`. So
`common/shims/Control/Monad/Reader.hs` has the two instances mtl used to
supply:

```haskell
instance MonadFail (Either String)       where fail = Left
instance MonadFail m => MonadFail (ReaderT r m) where fail msg = ReaderT (\_ -> fail msg)
```

This also keeps the failure a `Left`, which is what happy's callers match
on; an `error`-based instance would compile and then misbehave on any parse
error. `ghc622/shims-ghc/GhcCompat.hs` applies the same rule throughout.

---

## D13 — happy's GLR backend is shadowed, not patched

`ProduceGLRCode.lhs` does not compile under mhs (`Cannot satisfy
constraint: [] ~ ([Char] ->)`: in `fmap (span p . lines) header` with
`header :: Maybe String`, mhs resolves the `Functor` at `((->) a)`). GHC's
grammars never pass `--glr`, so `happy/noglr/ProduceGLRCode.hs` provides the
same interface with `produceGLRParser` raising an `IOError` and sits earlier
on the `-i` path. happy's source is untouched (D11), and the result is
correct for every grammar that does not use `--glr`. Whether this is an mhs
inference bug is not investigated.

---

## D14 — happy is verified by regeneration, not by equality with a GHC-built happy

The GHC-built generator was a 1.19.12, and 1.19.12's output differs from
1.19.5's by the `happyExpList` feature, so equality between the two is the
wrong test. The check is generational, as for MicroHs (D1): the happy built
from the seed regenerates its own parsers byte for byte. The `Paths_happy`
shim states version 1.19.5, since happy stamps the version into every file
it writes.

---

## D15 — GHC's unboxed types are shims; only unboxed string literals need patches

mhs lexes unboxed literals (`0#`), has pattern synonyms and accepts
`.hs-boot` files. So `ghc622/shims-ghc/` defines `type Int# = Int` and
`pattern I# x = x` (and the rest), and GHC's `case n of I# n#` compiles
unmodified at every use site. What cannot be shimmed is lexical: an unboxed
string literal `"…"#`, which patch 0002 removes (D45).

Rule: settle what mhs refuses with a probe of a few lines before writing a
patch. Static counts of what GHC *uses* say nothing about what mhs
*rejects*.

---

## D16 — GHC is patched for mhs's stricter unlit, not mhs

mhs's literate-Haskell reader matches the `\begin{code}`/`\end{code}` lines
exactly, so a delimiter with trailing whitespace stays in (or out of) the
code block. GHC's own `unlit` tolerates it. Fixing mhs would change the
verified seed (D1), so `ghc622/patches/0001-unlit-trailing-space.patch`
deletes the trailing spaces instead: every hunk is a deleted space. MicroHs
0.17.0.0 still has the strict reader (D58). The patch goes when MicroHs's
reader tolerates trailing whitespace.

---

## D17 — GHC 6.2.2 is preprocessed with `-D__GLASGOW_HASKELL__=408`

`HsVersions.h` maps `GLAEXTS`, `DATA_BITS`, `UNSAFE_IO` and the like to the
pre-hierarchical modules (`GlaExts`, `Bits`, `IOExts`) when
`__GLASGOW_HASKELL__ < 504`, and those are what the shims provide; the
`>= 504` branches want `GHC.Exts`, `GHC.IOBase` and `GHC.Handle`. Two
consequences are handled where they arise: `SysTools` takes its `< 603`
branch, hence the `CForeign` and `Foreign` shims in `ghc622/shims/`, and the
driver takes its pre-5.01 catch-all handler, which patch 0026 replaces under
`__MHS__` (D47). The other four defines are the driver's own (D19):
`-D__HASKELL__=98 -D__HASKELL1__=5 -D__HASKELL98__ -D__CONCURRENT_HASKELL__`.

---

## D18 — Hugs is patched for pattern guards, not MicroHs's source

`hugs/patches/0002` adds pattern guards to Hugs's parser. That fixes the seed
compiler once, for every program it compiles, rather than rewriting
MicroHs's own pattern guards into `case` expressions, which would need
redoing each time MicroHs gains one. Upstream's Hugs
(augustss/hugs98-plus-Sep2006, which MicroHs's CI builds with) carries the
same change as c447d1c0 and `0003` as ede690a3. This repository's `0002`
also computes each value derived from the Hugs stack before pushing it:
`push(c)` is `stack(++sp)=(c)`, and C leaves unspecified whether `sp` is
incremented before `c` reads the stack. gcc reads first, so upstream's copy
works when built with gcc; a compiler that increments first breaks every
guard with a pattern, a `let` or more than one condition.

---

## D19 — GHC's own build system is the specification for compiling it

Before shimming or patching anything, check what GHC's Makefiles, configure
script and driver pass for it. With GHC the build system is part of the
compiler: much of what looked like porting problems was GHC being compiled
differently from how it compiles itself. Concretely, stage 1 is compiled
with the driver's cpp defines (D17), `Config.hs` is generated as the Makefile
generates it (`ghc622/tools/config-hs.sh`), the configure script is run
rather than replaced (D31), and from 6.2.2's own make build on (D52) every
version is built by its tarball's own build system.

---

## D20 — The raw-memory modules are reimplemented, not emulated

GHC's `FastString`, `StringBuffer` and `PrimPacked` poke bytes through
`Addr#` and `ByteArray#`. Reimplementing what they export is less work and
more trustworthy than emulating the primops on MicroHs:

- `ghc622/shims/FastString.hs` is a `String` plus an interned `Int`.
  Interning is load-bearing: `Unique.getUnique` is `uniqueOfFS`, so equal
  strings must get the same `Int` or name resolution breaks. It must also be
  re-entrant: a name derived while its parent is being interned (`$w…`,
  `$s…`, `$f…`) gets its own unique, or the interface dictionary, keyed by
  unique, conflates the two. The shim defines no `Show` instance; the one
  in `Outputable` is the only one.
- `StringBuffer` is a shim over an immutable `Array Int Char` with 6.2.2's
  API, copied function by function, including the NUL sentinel the lexer
  relies on.
- `PrimPacked` is not needed: its users are the two modules above.

`utils/Binary.hs` follows the same rule (patch 0004): the byte loops are
portable Haskell, the wire format is the pristine one.

---

## D21 — GHC-only syntax is removed by mechanical patches that never cross a line

`SLIT`, `'c'#`, `_scc_`, `do { ;`, doubled commas, `f.g` and the rest are
removed by mechanical patches; the
[ghc622 README](ghc622/README.md) lists them by cause. Rule for any such
patch: a pattern that deletes text must never match a newline. Deleting a
`_scc_` annotation inside a comment together with the newline after it
joins the next line onto the comment, which silently deletes code rather
than failing to apply. Read each patch as a diff for that reason.

---

## D22 — mhs compiles GHC in dependency order, and duplicate import items are patched out

**Order.** `ghc622/tools/build-order.py` computes the dependency order, as
GHC's `mkdependHS` does, and mhs compiles one module at a time in that order,
sharing its `-C` cache. Asked for `Main` alone, mhs walks the graph itself,
and in a tree with 31 boot modules a module bound to its `.hs-boot` early is
never promoted to the real module, so a later import of it sees no data
constructors.

**Duplicate items.** GHC tolerated a name listed twice in one import list
(`WorkerInfo(..), …, WorkerInfo`); mhs rejects it and reports the name as
"not exported". Patch 0012 deletes the second occurrence. MicroHs 0.17.0.0
accepts duplicates (D58); the patch stays until the series is pruned.

When an error names something that demonstrably is exported, read the
offending line before building a theory about module resolution.

---

## D22a — Boot files GHC never had are written by hand

GHC's `.hi-boot` files are interfaces, so `PprType.hi-boot` can name
`Type.PredType` without creating a build edge. mhs's `.hs-boot` files are
real modules, so the same reference imports `Type` and re-forms the cycle
`Type -SOURCE-> PprType -> Type`. `ghc622/hsboot/Type.hs-boot` declares
`PredType` abstractly so that `PprType.hs-boot` can SOURCE-import `Type`;
`CgMonad`, `DsUtils` and `HsPat` follow the same pattern, and boot modules
SOURCE-import one another for the same reason.

---

## D24 — Lazy IO is where MicroHs's semantics differ from GHC's

Two of GHC's uses of lazy IO behave differently on the MicroHs runtime, and
both are fixed so that they are correct under either semantics:

- `fixIO` is defined once in `GhcCompat` with an `IORef` and
  `unsafeInterleaveIO`. The obvious `fixIO k = fix (\ ~m -> m >>= k)` loops,
  and `TcRnTypes.fixM` uses `fixIO` for every recursive binding group.
- `UniqSupply.mk_supply#` was a CAF of type `IO UniqSupply`. GHC's
  `unsafeInterleaveIO` re-runs it at each node of the supply tree; MicroHs
  memoised it, so every node got the same unique. Patch 0006 gives it a
  parameter, so each occurrence is a distinct application. MicroHs 0.17.0.0
  re-runs it (D58); the patch stays.

Anywhere a program relies on `unsafeInterleaveIO` or `unsafePerformIO`
re-executing is a place to check first.

---

## D31 — The tarball's configure script runs; probes that 2026 compilers break are repaired

`config.h` is never written by hand: the configure script a tarball ships is
run, and where a modern toolchain breaks one of its probes, the probe's
logic is rerun rather than its answer guessed. The shape is always a probe
that tests a proxy which no longer tracks the thing it cares about. In 6.2.2,
`FPTOOLS_CHECK_HTYPE`'s probes have a K&R `main()`, which gcc rejects, so
every `HTYPE_*` came out undefined; `ghc622/tools/gen-htypes.c` runs the same
logic and its output is appended to `config.h` (D47). Configure scripts are
used as shipped, not regenerated (D55).

---

## D41 — The 2004-era C is compiled with `-std=gnu89 -O`

The RTS headers declare functions such as `deRefStablePtr` `extern` and then
define them `extern inline`. Under GNU89 that emits no out-of-line copy and
no `.c` file provides one, so every call must be inlined: `-O` is required,
not a preference. Under C99 the meaning of `extern inline` is inverted and
the link fails with multiple definitions instead. GHC compiled its RTS with
`-O`, so this is what it always relied on. Everything the chain compiles is
also non-PIE (`-fno-pie`, `-no-pie`): nixpkgs' gcc defaults to PIE, which
moves info tables from `.rodata` to `.data.rel.ro` and puts static data
under ASLR. `.hc` is compiled with `-fwrapv` (D48).

---

## D45 — The mhs entry point is GHC 6.2.2

6.2 is the first GHC that knows x86-64. An x86-64 build of anything older is
an unknown-platform build, and 4.08.2's 1999 runtime, the obvious older
candidate, breaks on one 32-bit assumption after another. 6.2.x on x86-64 worked
in one configuration, unregisterised via C, which is the one mhs produces;
Debian, Ubuntu, Gentoo and OpenBSD shipped it. Registerised code, the native
code generator and GHCi arrived in 6.4.

What made 6.x reachable is one macro: `HsVersions.h` defines `SLIT`/`FSLIT`
unconditionally as unboxed `Addr#` literals (about 2,350 call sites), which
mhs cannot lex. Patch 0002 redefines them over a boxed `String`, with a
`LitString` in the `FastString` shim.

mhs compiles 6.2.2's compiler proper, configured for an x86-64 target so its
`.hc` output has 8-byte words; 6.2.2's own RTS and libraries take it from
there. The RTS needs three patches (`ghc622/rts/patches/`): cast-as-lvalue
sites, one `static`/`extern` mismatch in `GC.c`, and D50. 6.2.2 has no
x86-64 adjustors: a foreign-export wrapper calls `barf`.

---

## D46 — GHC 6.2.2's generated inputs: the lexer converted, the rest regenerated

- The three parsers (`parser/Parser.hs`, `parser/ParserCore.hs`,
  `main/ParsePkgConf.hs`) are regenerated by the chain's happy (D4) and
  adjusted for 2004's GHC (D49); the primop tables by a `genprimopcode` that
  mhs builds (`ghc622/tools/regen-generated.sh`).
- `parser/Lexer.hs` is the alex 2.0 output the tarball ships, because no alex
  exists before 6.2.2. Its DFA tables are `Addr#` string literals read with
  `indexInt16OffAddr#`, which mhs cannot compile, so
  `ghc622/tools/convert-lexer.py` keeps the literals and decodes them once,
  at startup, into a boxed `Array Int Int`; the DFA and the token actions are
  untouched. D57 checks the shipped DFA against alex 2.1.0.
- The `SrcLoc` fields are strict (patch 0025). Under the shims `FastInt` is
  a lazy `Int`, so lexing built one thunk per character and overflowed the
  mhs stack on very long lines.
- GHCi and the ILX and Java back ends are not built.

---

## D47 — On the MicroHs runtime, stage 1 wraps arithmetic and retries without strictness analysis

Stage 1 is GHC 6.2.2's source running on the MicroHs runtime, which traps
arithmetic that GHC wraps. Each case is handled where it arises:

| gap | where it bites | fix |
|---|---|---|
| `+ - *` on `Int` raise with `WANT_OVERFLOW 1` | CSE's `hash_expr` wraps on purpose | the runtime is built with `WANT_OVERFLOW 0` (`ghc622/nix/stage1.nix`) |
| `fromInteger` into `Int8/16/32` is checked | `Binary Integer`'s sign byte, `Literal`'s `narrow*Lit` | wrapped by hand (patch 0026) |
| `negate`/`abs` of `minBound` raise, whatever `WANT_OVERFLOW` says | `hashExpr` | test for `minBound` first (0026) |
| no `hFileSize` | `readBinMem` | read the file whole by its path (0026) |
| the pre-5.01 catch-all handler (D17) swallows `ExitException` | every clean exit | the `>= 501` branch under `__MHS__` (0026) |
| a text handle decodes UTF-8 | `GetImports` on the Latin-1 `Ctype.lhs` | `readBinaryFile` (0026) |

Space is the other limit: on some modules the demand analyser exhausts the
MicroHs stack and heap, because GHC's own strictness analysis kept
`dmdFix`'s chains short when GHC compiled itself. The stage-2 and `base`
builds retry a failing module with `-O -fno-strictness`, then `-O0`
(`ghc622/nix/stage2.nix`, `base.nix`).

MicroHs 0.17.0.0 still traps the narrowing case; its `negate` follows
`WANT_OVERFLOW` as `+ - *` do (D58). Patch 0026 stays whole until the series
is pruned.

---

## D48 — `.hc` is compiled with `-fwrapv`

`GHC/Show.lhs` detects `minInt` with `negateInt# n# <# 0#`, which gcc deletes
under the signed-overflow rule, so `show (minBound :: Int)` printed `-0`.
Every `.hc` compile passes `-fwrapv`, as GHC itself did from 6.8.

---

## D49 — happy 1.19.5's output is adjusted for GHC 6.2.2

`ghc622/tools/fix-generated-parsers.sh` makes three rewrites to each parser
happy writes, each a 2020s template habit that a 2004 compiler rejects:
`{-# OPTIONS_GHC -w #-}` becomes `{-# OPTIONS -w #-}` (6.2.2 reads `_GHC`
as a flag); the template's `Control.Applicative` and `Control.Monad (ap)`
imports go (2004's `base` has neither, and with `%monad` nothing uses them);
and `(P) HappyAbsSyn` becomes `P HappyAbsSyn` (6.2.2 does not expand a type
synonym in parentheses during unification). 6.2.2's own make build runs
happy through a wrapper that applies it (D52).

---

## D50 — The RTS's megablock map gets a fixed base and a window

6.2.2's 64-bit `HEAP_ALLOCED` (marked "XXX: This is a HACK" in the source)
keys a 4096-entry map on the low 32 bits of an address. With `HEAP_BASE 0`
the heap starts wherever `mmap(NULL)` puts it, so under ASLR its low 32 bits
alias the executable's static closures in about one process in 400, and the
collector then evacuates static closures as heap objects.
`ghc622/rts/patches/0003-mblock-map-window.patch` sets `HEAP_BASE
0x500000000` on x86-64 and keys a 65536-entry map on `p - HEAP_BASE` (a
64 GB window), with `getMBlocks` refusing memory outside it. This is what
6.4 did in spirit, a fixed heap base, without its two-level map; the window
is enough under the 8 GB address-space limit every compile runs with.
Disabling ASLR was rejected: it moves the bug to the next machine.
`build/rts622/alias-test/` reproduces the aliasing.

---

## D51 — The 6.2.2 fixed point: stage 5 equals stage 4 in all 220 modules

The acceptance check for the 6.2.2 chain is `nix-build -A
ghc622.fixpoint` (by hand, `build/Makefile`'s `compare3`, `compare4`,
`compare5`), which compares the `.hc` each stage writes, module by module:

- stage 3 against stage 2 is reported only: stage 2 was compiled by stage 1,
  whose shims give other `FastString` uniques;
- stage 4 against stage 3 is reported: they differ in `CoreUtils` (one SRT
  with two entries swapped, since Unique order follows evaluation order) and
  may differ in `Pretty`, whose `Float` literal has an uninitialised upper
  word;
- stage 5 against stage 4 must be identical in all 220, or the build fails.

Neither stage-3/4 difference propagates: a compiler that differs only in
them writes the same output. The `Pretty` one is a 6.2.2 defect on 64-bit
(`PprAbsC.floatToWord` reads a 4-byte float back as an 8-byte word) and is
left unpatched in the pristine source the native stages compile, since
compiled programs never see it (`PK_FLT` reads the low word). A
bit-reproducibility requirement would fix it with a `.&. 0xffffffff`, or
6.4's `castFloatToWord32`.

---

## D52 — 6.2.2 builds itself with its own build system; every GHC before 8.0 gets GMP 6.1.2

**6.2.2 by its own `configure && make`.** `nix-build -A ghc622` is 6.2.2
built by its own build system with the chain's stage 3 as `--with-ghc`
(`ghc622/nix/inst.nix`, the boot compiler being `ghc622/nix/boot.nix`).
Stages 1 to 3 exist because that build system needs a working GHC to drive
it: stage 3 is the first compiler built from the pristine source by a native
one, and it is the boot compiler. Stages 4 and 5 are the fixed-point check
(D51). From `inst.nix` on, the build system is the compiler's own. The 220 compiler modules this 6.2.2 compiles are
byte-identical to stage 4's, `.hc` and `.hi`. A 2026 host needs: the three
RTS patches (D45), the `gen-htypes` block in `mk/config.h` (D31),
`-D_GNU_SOURCE` for hsc2hs and the C bits, the private `execvpe`
declarations of `libraries/unix` and `hslibs/posix` removed (glibc has its
own, with other types), the C flags carried in the rts package's
`extra_cc_opts`, a `happy` wrapper applying D49 (with `GHC_HAPPY_OPTS` and
`SRC_HAPPY_OPTS` emptied), and the make output searched for `*** [`,
because fptools' loops carry on past a failing subdirectory and `make` still
exits 0.

**Every later version is one `configure && make` derivation**, or one
Hadrian derivation from 9.8.4 (D53, D54). Each release's `configure.ac`
names the oldest GHC that may build it; the shortest chain is 6.2.2 → 6.6 →
6.10.4 → 6.12.3 → 7.4.2 → 7.8.4 → 8.0.2 → 8.4.4 → 8.8.4 → 9.0.2 → 9.4.8 →
9.8.4 → 9.12.4 → 9.14.1.

**Registerised from 6.12.** The unregisterised 6.10.4 builds 6.12.3 with
`GhcUnregisterised = NO`, `GhcWithNativeCodeGen = YES` and `-fasm` for the
libraries and stage 2: its stage 1 generates native x86-64 code for
everything else, and every later compiler is registerised (`registerised ?
true`), which makes each several times faster to build. 6.12.3's
`includes/Rts.h` blocks for `__GNUC__ > 4`, never compiled in 2010, are
disabled.

**GMP.** GMP 6.2 made `mpz_init` lazy: a zero result that an mpz function
returns early keeps `_mp_d` at a static dummy limb in libgmp instead of
memory the GHC runtime allocated. Every GHC before 8.0 takes `_mp_d -
sizeof(StgArrWords)` as the `ByteArray#` closure, so the collector evacuates
a pointer into libgmp's data segment and dies when the word there is not an
info pointer. `common/test/GmpZero.hs` keeps 2.4 million such zeros live
across collections and is part of every install check from 6.2.2 to 8.0.2
(8.0.2's against the host's GMP).
`gmp612/default.nix` builds GMP 6.1.2, the last release before the change,
and every build before 8.0 takes it (stage 2's link, stages 3 to 5, boot,
inst, happy 1.16, alex 2.1.0, 6.6 to 7.8.4). 8.0's integer-gmp works on limbs
and is fine with any GMP. Rejected: patching the RTS and integer-gmp to copy
such results (two code bases; the distributions' answer to the bug was the
GMP version too), and GHC's in-tree GMP 4.1 (a port of its own under
gcc 15). A program these compilers build outside Nix binds to whatever
`libgmp.so.10` the loader finds unless GMP 6.1.2's directory is on its path;
inside Nix the cc wrapper's rpath takes care of it.

---

## D53 — 8.0.2 to 9.4.8 by `configure && make`; Hadrian from 9.8.4, through `bootstrap.py`

Each version below is built the way nixpkgs and Guix build that release; none
of the fixes is about the boot compiler.

- **8.0.2**: `-std=gnu89 -fpermissive -fwrapv`, which the 2004-2012 sources
  need under gcc 15, break integer-gmp's C99 cbits, so 8.x and later take
  `-std=gnu11 -w`. iserv links `-lHSrts_thr`, so the threaded RTS way is
  built (`GhcRTSWays = thr`).
- **8.4.4**: configure takes `CC=gcc` (`--with-gcc` is obsolete).
- **8.8.4**: configure takes `GHC=`. A GHCi-less 8.8.4 does not compile
  (`DynFlags.hs` imports `Foreign (Ptr)` only `#if defined(GHCI)`, while
  `SHARED_GLOBAL_VAR` needs it from stage 2), so **from 8.8 on the chain
  builds GHCi and SMP**, the configuration everyone else builds; a NOSMP
  threaded RTS rejects `-N` and `-qg`, and Hadrian links itself with
  `-with-rtsopts=-I0 -qg`. 6.2.2 to 8.4.4 keep both off: they only compile
  the next version. Rejected: a one-line patch moving the import, which would
  make the chain's 8.8 a configuration nobody else has.
- **9.0.2, 9.4.8**: the make build links `rts/StgCRunAsm.S` on every
  architecture, and on x86-64 it is an object with no `.note.GNU-stack`.
  `ghc90/StgCRunAsm-only-when-needed.patch` is Guix's copy of upstream
  d61f7428; the copy on GitLab joins its `$(findstring …)` with spaces and is
  a no-op. The install check asserts `StgCRunAsm.o` absent from
  `libHSrts.a`.
- **9.0 to 9.14** record a GMP library directory only when configure is
  given `--with-gmp-libraries`, and without one a compiler cannot link a
  program outside Nix; configure gets `--with-gmp-includes/-libraries`, and
  the install check asserts the directory (D54 for where 9.14 records it).
- **9.4.8 by make.** Its tarball still carries `mk/` and `ghc.mk`, and
  `configure.ac` allows make for a boot compiler older than 9.1; nixpkgs
  and Guix build 9.4 with make too.
- **9.4 to 9.14** declare `build-tool-depends` on happy and alex, which the
  chain builds and runs (D55).
- **9.8.4** has `hp2ps`'s `extern void *realloc();`, which C23 reads as a
  function of no arguments: `ghc98/hp2ps-C-gnu17.patch`, upstream's fix from
  9.10.

**Hadrian from 9.8.4, by `bootstrap.py`.** 9.8.4's Hadrian has 18 Hackage
dependencies, ordinarily built by cabal-install. GHC ships
`hadrian/bootstrap/bootstrap.py` for packagers: given a bare GHC and a
bootstrap plan (each dependency's version, revision and sha256), it builds
each dependency with its `Setup.hs` into a private package database, then
Hadrian. The chain uses it, as Guix does. The plan is copied from the
tarball verbatim and read with `builtins.fromJSON`; Nix fetches the tarballs
and revised `.cabal` files with the plan's hashes, so the build needs no
network. The plan's boot-library versions are rewritten to what the boot
compiler has (`ghc-pkg field pkg version`). Flavour: `default` with
`no_dynamic_libs`, `no_dynamic_ghc`, `no_profiled_libs`,
`no_split_sections`, `--docs=none`; Hadrian's `install` target builds the
binary distribution and installs it.

---

## D54 — One Hadrian derivation for 9.8.4, 9.12.4 and 9.14.1

`common/hadrian-ghc.nix` takes the version, tarball hash, boot compiler,
happy and alex, plan and patches as parameters; `ghc98`, `ghc912` and
`ghc914` are calls of it.

**9.12.4 is on the ladder** because configure's floor for 9.14.1 (`9.6`) is
stale: 9.14's Hadrian no longer builds ghc-heap at stage 0, and its ghci
wants the boot compiler's `ghc-internal`, which exists from 9.10. A 9.8 boot
fails configuring ghci. 9.12.4 is the newest release a 9.8 can build, and
9.14.1 builds from it.

**What 9.14.1 needs with a 9.12.4 boot.** 9.14.1's `GHCi/Message.hs`
defines `Binary HalfWord` only `#if MIN_VERSION_ghc_internal(9,1400,0)`,
but 9.12.3 backported the `HalfWord` newtype, so a 9.12.4 boot has the
newtype and no instance. The ghc-9.14 branch guards it with
`MIN_VERSION_GLASGOW_HASKELL(9,12,2,20250919)`; that one line is
`ghc914/ghci-Binary-HalfWord-9.12.3-boot.patch`. 9.14's `ghc-bignum` is a
shim over `ghc-internal`, which records the GMP directory, so the install
check looks there (`gmpPackage`).

None of the patches nixpkgs applies to 9.12.4 and 9.14.1 is for x86-64
Linux with glibc. The host fixes for the Hadrian builds are the hp2ps patch
(9.8 only) and the HalfWord guard (9.14.1 only); everything else is the
tarballs' own build systems, driven as their packagers drive them. When
9.14.2 is released, its source should be checked for the branch's guard and
the patch dropped; a 9.16 will want the 9.14's plan treatment.

---

## D55 — Generated code in the inputs: parsers and lexers are regenerated from their grammars

**What the tarballs ship, and what happens to it.**

- Regenerated or rebuilt by the chain: Hugs's `parser.c` (bison),
  MicroHs's `generated/*.c` (D1), cpphs (from source), happy 1.16 and
  1.20.1.1, GHC 6.6's seven generated modules, 7.4.2's `ghc-pwd`. Prebuilt
  objects that a build does not use are deleted in `postUnpack` (7.4.2's
  `utils/ghc-pwd/dist-boot`, 9.0.2's containers `dist-install` and
  `utils/hsc2hs/test.o`), so "not used" is enforced.
- Seeds, each discharged: happy's (D7), the `Scan.hs` of alex 2.1.0 and
  3.2.7.4 (fixed points, and diverse double compilation, D57).
- Used as shipped: 6.2.2's `Lexer.hs` (D46, its DFA checked by D57); the
  `Scan.hs` of the alex 3.5.2.0 in 9.12.4's Hadrian bootstrap plan, which has
  no check.
- `configure` scripts: autoconf output, **used as shipped**, as Guix and
  nixpkgs do (Debian regenerates). Where bootstrapping practice is strict is
  parser-generator output (live-bootstrap rebuilds bison's parser from its
  `.y`), which is the rest of this entry.

**The grammars are in the tarballs.** GHC's sdist renames each grammar
`<name>.source` so that a build never runs happy or alex; 6.10 to 7.8 ship
the cpp'd `Parser.y.pp.source`. `common/regen-parsers.sh`, in `postPatch`,
moves every shipped generated module to `$NIX_BUILD_TOP/shipped/<path>`,
gives each grammar its name back, and for Cabal's lexer runs its Makefile's
rule (`alex --latin1 --ghc`, `cat -s`). The tarball's own rules then
regenerate everything. `common/cmp-regenerated.sh` compares each
regenerated module with the shipped one (through `ghc66/cmp-generated.sh`,
which ignores LINE pragmas and raw cpp line markers): a difference fails the
build when the happy on PATH is the version named in the shipped file's
header (8.0.2 by 1.19.5, 9.0.2 by 1.19.12, 9.8.4 to 9.14.1 by 1.20.1.1), and
is reported otherwise and for alex output. The build does not depend on
the shipped file; agreement is evidence on top.

**The generators** each version's configure accepts, and the ones the chain
uses:

| GHC | happy floor | alex floor | used |
|---|---|---|---|
| 6.10.4 | >= 1.15 | >= 2.1.0 | 6.6's happy 1.16 and alex 2.1.0 |
| 6.12.3, 7.4.2 | >= 1.16 | >= 2.1.0 | the same |
| 7.8.4 | >= 1.19 | >= 3.1.0 | 7.4.2's happy 1.19.5 and alex 3.2.7.4 |
| 8.0.2, 8.4.4 | >= 1.19.4 | >= 3.1.0 | the same |
| 8.8.4 | >= 1.19.4 | >= 3.1.7 | the same |
| 9.0.2 | >= 1.19.10, < 1.20 | >= 3.1.7 | 8.8.4's happy 1.19.12, 7.4.2's alex |
| 9.4.8 to 9.14.1 | 1.20.x (9.14: or 2.0.2 to 2.1) | >= 3.2.6, < 4 | 9.0.2's happy 1.20.1.1, 7.4.2's alex |

Each happy is built like `ghc94/happy120.nix`: the tarball's parsers set
aside, generation 1 from the grammars by the mhs-built happy 1.19.5, its
`-agc` output compared with the shipped parsers, generation 2 the fixed
point. Specifics:

- **happy 1.19.5 by 7.4.2** (`ghc74/happy1195.nix`) needs mtl, which 7.4.2
  builds but does not install; `ghc74/mtl.nix` builds the tree's mtl 1.1.1.1
  into a package database of its own. Its `Setup.lhs` cpp's the templates
  and keeps a raw line marker when cpp writes more than one flag after the
  file name (the bug `ghc66/cpp-template.sh` fixes for 1.16), so the
  derivation redoes that step with the fixed one. Its parsers match the
  shipped ones, written by 1.19.4, modulo `import Control.Monad (ap)`.
- **happy 1.19.12 by 8.8.4** (`ghc88/happy11912.nix`). 1.19.6 and later
  want an mtl that 7.4.2 does not have. 1.19.12's tarball has neither
  grammars nor template sources, so those come from the 1.19.12 tag. Its
  templates are cpphs output (`gen-happy-sdist`): the chain's cpphs, run as
  `cpphs --linepragma -D<flag>… templates/<src>`, reproduces all thirteen
  byte for byte, and the check is `cmp`. The shipped parsers carry
  1.19.10's template, which gcc preprocessed, so generation 1 also writes
  both parsers with `--template` set to a gcc-made template (from
  `ghc66/cpp-template.sh` and 8.8.4) for the comparison; the installed happy
  keeps 1.19.12's own templates.
- **One alex, 3.2.7.4 by 7.4.2** (`ghc74/alex327.nix`), for 7.8.4 to
  9.14.1. alex 3.1.x depends on QuickCheck, which 7.4.2 does not have; 3.2.4
  dropped it. 3.2.7.4's `-g` output compiles under 7.4.2, and its templates
  are plain source.

**Where the checks run.** Every fixed-point and comparison check is in
`checkPhase` with `doCheck = true`: the build makes every artefact
(generation 3, round 3, the regenerated parsers) and the check only
compares, so a build with checks disabled installs the same output. The
installed-tree checks (`--version`, `T3`, `GmpZero`, the GMP directory) are
in `installCheckPhase`. The 6.2.2 fixed point is its own derivation (D51),
reachable as `ghc622.fixpoint` and `ghc622.tests.fixpoint`.

---

## D56 — happy's seed, by diverse double compilation from happy 1.15

The `Happy_1_15` tag of happy's repository commits the `Parser.hs` that
happy 1.14 wrote. It is not seedless, so the chain does not start from it,
but it is an independent producer of happy's parsers (proposed by Alexandre
Tunstall in [issue #2](https://github.com/andreabedini/ghc-bootstrap/issues/2)).
`nix-build -A happy.ddc115` (`build/ddc-happy115.sh` outside Nix), each step
compiled by the chain's mhs:

```
happy 1.15  from the Parser.hs that happy 1.14 wrote
genA        happy 1.15 generates happy 1.19.5's Parser.hs and AttrGrammarParser.hs
happyA      happy 1.19.5 from genA
genB        happyA regenerates them    -> must equal happy/happy-seed/
```

genB is `happy/happy-seed/` byte for byte. The seed is what two unrelated
starting points converge on, a happy built with GHC 9.14 and a happy 1.14
from 2005, so a compromise carried in it would have to be in both. genA is
not compared with anything: 1.15 writes different code from 1.19.5.

mhs compiles both sides, so this says nothing about mhs (that is D1). The
check is a derivation of its own, so happy's derivation, and the chain after
it, do not depend on it.

---

## D57 — alex's own lexer, by diverse double compilation from a hand-written scanner

alex's lexer, `src/Scan.hs`, is alex output, and every alex tarball ships
it; an alex built with mhs still runs that generated file, so regenerating
GHC's lexers with it discharges nothing (Janus Troelsen, Discourse thread
6205 #102). `ghc66/alex210ddc/Scan.hs` is a scanner for alex 2.1.0 written
by hand from `Scan.x`: it copies `Scan.x`'s Haskell and writes each macro and
rule as a regular expression over a few combinators, taking the longest
match with the earlier rule winning a tie, as alex's DFA does. Every alex
below is compiled by the chain's mhs:

```
alexA   alex 2.1.0 with the hand-written Scan.hs
genA    alexA on Scan.x                -> the tarball's Scan.hs, modulo blank lines and LINE pragmas
alexB   alex 2.1.0 with genA
genB    alexB on Scan.x                -> genA, byte for byte
step 1  alexB on 3.2.7.4's Scan.x      (2.1.0 accepts it as it is)
alex3A  alex 3.2.7.4 with step 1's Scan.hs
gen3A   alex3A -g on src/Scan.x        -> the tarball's src/Scan.hs, byte for byte
alex3B  alex 3.2.7.4 with alex3A's plain output
gen3B   alex3B on Scan.x, -g and plain -> gen3A's, byte for byte
```

The first four lines are `ghc66.alex210ddc`, the rest `ghc66.alexChain`.
mhs cannot compile `-g` output (unboxed `Addr#` tables), so each alex 3 is
built from plain output and the `-g` output is what is compared.

`ghc66.alexChainLexers` ties these to the alexes the GHCs use: it runs
`ghc66.alex210` against alexB, and `ghc74.alex327` against alex3B, on every
alex grammar of the releases each one serves, with the chain's flags, and
compares alex 3.2.7.4's own `Scan.hs` from each; every pair must be
byte-identical. `alex210ddc` also runs alexA and alexB on 6.2.2's `Lexer.x`
and compares alexB's output with the shipped `Lexer.hs`
(`alex210ddc/cmp-tables.pl`): the four DFA tables read as integers and
`alex_accept` are the same, as are the 1,010 lines of Haskell before alex's
template, modulo `LINE` pragmas, blank lines and the `ghcconfig.h` include
2.1.0 adds.

The chain's alexes still start from their tarballs' `Scan.hs`: switching
them to the hand-written path would change every GHC derivation from 6.6 on
and build them from the same bytes. What the scanner is trusted for is its
output, the shipped `Scan.hs`, not correctness on every input. mhs compiles
every alex here (D1).

---

## D58 — The chain runs on MicroHs 0.17.0.0

`mhs/default.nix` builds MicroHs 0.17.0.0 (the `v0.17.0.0` tag; the hash is
`nix hash path` of `git archive v0.17.0.0`) from its own `hugs/` tree with no
patch: the Hugs-derived compiler reaches the fixed point and reproduces the
shipped `generated/mhs.c` (D1). On it, the 6.2.2 fixed point holds
(D51), and `nix-build -A ghc914` builds the whole chain to GHC
9.14.1 with no change above 6.2.2. `mhs/bootstrap-seed.sh` and the `build/`
scripts run on 0.16.8.0, with `mhs/patches/0001`.

0.17.0.0 rejects a second instance of the same class and type, so the
`FastString` shims define no `Show` instance (D20). Its stage 1 compiles
`base` differently from 0.16.8.0's, nearer to a native 6.2.2: 737 `$w`
worker closures in `libHSbase.a` against 574, the native make build having
733. Which change in MicroHs is responsible is not identified. So stage 3 to
5 outputs are not byte-equal across MicroHs versions: `base`'s interfaces
come from stage 1.

**Where 0.17.0.0 stands on the problems the 6.2.2 series works around**
(thread 6205 #98), each reduced to a small program:

| 0.17.0.0 | Items (GHC 6.2.2 patch) |
|---|---|
| fixed | an empty statement after `do {` (0010); trailing commas (0011, part); `f.g` (0015); `f :: T = e`, on one line or with `= e` on the next (0022); an import item listed twice (0012); `T(..)` importing field selectors exported by name (0013); mhs's own `MachDeps.h` shadowing an `-I` directory (0003); `hFileSize` (0026, part); `negate`/`abs` of `minBound`, which follow `WANT_OVERFLOW` (0026, part); `unsafeInterleaveIO` in a CAF, which re-runs (0006); `'x'#` (0007) |
| in part | `"abc"#` is a ByteString literal, not an `Addr#` (0002, 0005) |
| not fixed | unlit with trailing whitespace (0001); `_scc_` (0009); doubled commas (0011; GHC 9.14.1 rejects them too); safety after the entity string and `foreign label` (0017); `fromInteger` into Int8/16/32 still traps (0026, part) |
| worse | a Latin-1 byte in text input raises `hGetContents: surrogate` (0.16.8.0 decoded it wrongly without a word) |
| not mhs bugs | a hand-written `Typeable` instance (0021) and an import of a name that is not exported: GHC 9.14.1 rejects both |

The 6.2.2 patch series keeps every patch: each removes a GHC-ism or works
around a semantic difference, so each is still correct under 0.17.0.0.
Dropping the ones 0.17.0.0 makes unnecessary is a separate change. Text
input that is not UTF-8 fails under 0.17.0.0. Of the chain's inputs, only
6.2.2's `parser/Ctype.lhs` (transcoded by patch 0008) and two ObjectIO
modules the chain does not build are not UTF-8; the happy, alex, cpphs and
polyparse tarballs, and every `.y`, `.ly` and `.x` file of GHC 6.6 to
9.14.1, are.

---

## D59 — Repository files describe the current state; history is in commit messages

READMEs, this file and the other documents say what is true now. How the
project got there, what was tried and dropped, and when, belongs in commit
messages, where `git log` keeps it with the change it explains. A decision
that stops holding is removed from this file, not marked as overturned, and
the removing commit says why. Lab notes, logs and findings files are not kept
in the tree: a finding that still matters goes into the document it concerns,
and the evidence for a change goes into its commit message.
