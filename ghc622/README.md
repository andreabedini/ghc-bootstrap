# GHC 6.2.2

This is where the chain enters GHC (since [D45](../DECISIONS.md#d45--d44-overturned-the-entry-point-moves-to-ghc-622)). [mhs](../mhs/README.md)
compiles GHC 6.2.2's compiler proper. That compiler builds 6.2.2's runtime and
libraries, then compiles its own source, until stage 5's Abstract C is
byte-identical to stage 4's. Finally 6.2.2's own `configure && make` builds the
installed compiler, with stage 3 as the boot compiler, and that is what builds
[GHC 6.6](../ghc66/README.md).

6.2.2 is the first GHC with an x86-64 port: unregisterised, via C, with no
GHCi and no native code generator ([`build/research-6.2-x86_64.md`](../build/research-6.2-x86_64.md)). Why I
started here and not at 4.08.2 is in the [top-level README](../README.md#how-i-found-the-route).

## Building

| Attribute | What it builds | File |
|---|---|---|
| `ghc622` | 6.2.2 by its own configure and make, with stage 3 as the boot compiler: the installed compiler | `nix/inst.nix` |
| `ghc622.boot` | stage 3, wrapped as an installed compiler for `inst.nix` | `nix/boot.nix` |
| `ghc622.tree` | the source tree with its generated files regenerated | `nix/tree.nix` |
| `ghc622.rts` | the runtime system, `libHSrts.a`, compiled without a GHC | `nix/rts.nix` |
| `ghc622.stage1` | the compiler proper, compiled by mhs | `nix/stage1.nix` |
| `ghc622.base` | `libraries/base`, compiled by stage 1 | `nix/base.nix` |
| `ghc622.stage2` | the native compiler, compiled by stage 1 | `nix/stage2.nix` |
| `ghc622.stage3`, `.stage4` | the compiler again, compiled by stage 2, then by stage 3 | `nix/native.nix` |
| `ghc622.stage5` | its `.hi` and `.hc` files compiled by stage 4, not linked | `nix/native.nix` |
| `ghc622.fixpoint` | checks that stage 5's `.hc` files equal stage 4's, module by module | `nix/fixpoint.nix` |

```sh
nix-build -A ghc622.fixpoint     # through stage 5, with the fixed-point check
nix-build -A ghc622              # the installed compiler
```

6.2.2's build system can't take over until there is a working GHC to drive
it. Stage 1 is GHC's source running on the MicroHs runtime: roughly twenty
times slower than a native compile, and it falls over on some modules at `-O`,
which then get retried with `-fno-strictness` and then `-O0`
(`stage2/flags.tsv`). That's why the 220 modules of stage 2 are compiled one by
one, in chunks a derivation can finish. The RTS and base are compiled by hand
for the same reason: their Makefiles call the compiler being built. Claude did
most of this module-by-module grind, and the logs under `build/` are its
running notes.

## Results

| Stage | Result |
|---|---|
| 6.2.2's compiler proper, typechecked by mhs | 226/235 modules, `Main` included |
| ... linked by mhs and gcc | a 2.9 MB `ghc` that answers `-B<topdir> --version` |
| `libraries/base` compiled by it | 147/147 modules to `.hi` and `.hc` |
| those `.hc` files compiled by gcc | 147/147 `.o` (`-fwrapv` is mandatory) |
| `ghc/rts`, unregisterised x86-64 | 78/78 objects, `libHSrts.a` |
| base's C files, `libHSbase.a` | built, no patches |
| `hsc2hs`, built with mhs | builds after 17 changed lines in its `Main.hs` (`hsc2hs/Main.hs.patch`, [`build/hsc2hs-mhs/FINDINGS.md`](../build/hsc2hs-mhs/FINDINGS.md)) |
| linking a Haskell program | zero undefined symbols |
| **running it** | **`putStrLn "hello"` prints and exits 0.** 12 programs (GC, Integer, Double, I/O, exceptions, `forkIO`, arrays, time/dir/random/regex) build and pass; rechecked 2026-09-23 |
| `libraries/haskell98` compiled by it | 30/30 to `.o`, `libHShaskell98.a` |
| **stage 2**: the compiler proper compiled by the mhs-built `ghc` | 220/220 modules, linked, compiles `Hello.hs` |
| **stage 3**: the same 220 modules compiled by stage 2, from the pristine source | 220/220, linked as `ghc-stage3`; its `Hello.hc` equals stage 2's |
| **stage 4**: compiled by `ghc-stage3` | 218 of 220 `.hc` identical to stage 3, all 220 `.hi` identical; [D51](../DECISIONS.md#d51--stage-3-and-stage-4-the-native-compiler-rebuilds-itself-218-of-220-modules-byte-identical) explains the two differences |
| **stage 5**: compiled by `ghc-stage4` | **220/220 `.hc` byte-identical to stage 4: the fixed point** |

The record is [D45](../DECISIONS.md#d45--d44-overturned-the-entry-point-moves-to-ghc-622) to [D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80), [`build/ghc622-mhs/FINDINGS.md`](../build/ghc622-mhs/FINDINGS.md),
[`build/ghc622-mhs/FINDINGS-link.md`](../build/ghc622-mhs/FINDINGS-link.md) and [`build/ghc622-stage2/LOG.md`](../build/ghc622-stage2/LOG.md).

## Files

| Path | What it is |
|---|---|
| `default.nix`, `nix/` | the derivations in the table above; the stages are a scope of their own |
| `patches/` | the compiler patch series, 0001 to 0026 (see below), generated from `series.conf` by `make-patch.sh` |
| `series.conf`, `make-patch.sh` | the series definition (each patch's header and hunk classes) and the script that splits the working tree's diff into patches with `tools/split-patch.py` |
| `reproduce-6.2.2.sh` | the compiler tree without Nix: the pristine tarball, the series, and the generated files |
| `rts/patches/` | three RTS patches: cast-as-lvalue (58 sites), a `static`/`extern` mismatch in the GC, and the megablock map window ([D50](../DECISIONS.md#d50--rts-patch-0003-the-megablock-map-gets-a-fixed-base-and-a-window)) |
| `rts/genapply-shim/` | the `Text.PrettyPrint` that `genapply` needs |
| `hsboot/` | 32 `.hs-boot` files for the compiler's module cycles, converted by hand from GHC's `.hi-boot` files |
| `shims/` | the ghc-on-mhs shims stage 1 needs on top of `common/shims`: `FastString`, `StringBuffer`, `Parsec`, `THSyntax`, ... |
| `shims-ghc/` | shims for GHC's own internal modules (`PrelBase`, `GlaExts`, `GhcCompat`, ...), first written for 4.08.2 |
| `shims-h98/` | the Haskell 98 modules (`List`, `IO`, `Monad`, ...) over MicroHs's library |
| `stage1/` | what linking stage 1 needs: `comb2c.py` (mhs's combinator output as a C array), C stubs and FFI glue |
| `stage2/` | per-module compiler flags (`flags.tsv`), the `Ctype.lhs` fix-up patch, and the `topdir` the stage-2 compiler runs with |
| `base/` | the build inputs for `libraries/base`: the modules that wait for `hsc2hs`, and the `topdir` that stage 1 compiles base with |
| `gen/config-hs.mk` | overrides for the compiler Makefile's `Config.hs` rule |
| `hsc2hs/` | `Main.hs.patch` (the `Parser` instances mhs needs) and a `System` shim |
| `tools/` | the scripts the build runs: module order, `Config.hs`, `hsc2hs` sources, `gen-htypes.c` (the `HTYPE_*` block gcc 16 stops configure producing), `convert-lexer.py` (alex's `Addr#` tables as boxed arrays), the regeneration of parsers and primop tables |
| `test/Hello.hs` | the acceptance test |

The shims are on the `-i` path in this order: `hsboot`, `shims`,
`common/shims`, `shims-ghc`, `shims-h98`.

## The patch series

`patches/` holds 26 patches (257 hunks in 102 files) against the pristine
tarball. Applied to a clean extraction, they reproduce the working tree. The
4.08.2 series had a large group of patches for x86-64; this one has none,
because 6.2.2 already knows x86-64 exists. Almost all of it is the Haskell of
2004 meeting the Haskell mhs implements.

| Group | Patches | What |
|---|---|---|
| Haskell that stopped being legal | 0002, 0005, 0007-0017, 0019-0022 | `SLIT`/`FSLIT` over boxed `String` (the [D44](../DECISIONS.md#d44--is-ghc-6x-within-mhss-reach-measured-not-estimated) blocker, 13 hunks); `Ctype.lhs` transcoded from Latin-1 (mhs's lexer wants UTF-8); `_scc_`; `do { ;`; double and trailing commas; duplicate and abstract import items; Functor/Applicative/MonadFail instances; `f.g` -> `f . g`; `(<>)` hidden; pre-addendum `foreign import`; unboxed literals; `f :: T = e` split; array indexing and pointer casts through `GhcCompat` |
| Portable serialisation | 0004, 0018 | `Binary.hs` without `ByteArray#`; float bit-casts |
| MicroHs runtime semantics | 0006, 0025, 0026 | the `mk_supply#` CAF (mhs memoises `unsafeInterleaveIO`); strict `!FastInt` in `SrcLoc` (a lazy `Int` under the shims); arithmetic that must wrap, `hFileSize`, `exitWith` (the gaps found in [D47](../DECISIONS.md#d47--the-compiler-links-runs-and-compiles-base-137143-modules-to-hc)); `GetImports` reading source as bytes |
| Build plumbing | 0003, 0023, 0024 | the `MachDeps.h` include path; a `#error GHC >= 5.00` guard; non-GHCi stubs in `TcSplice` |
| Bootstrapping proper | 0001 | `unlit` and a trailing space, as in 4.08.2 |

Again, only one patch is actually about bootstrapping.

**Nothing in the series is about x86-64.** The RTS patches in `rts/patches`
fix C that stopped being legal (58 cast-as-lvalue sites, one `static`/`extern`
mismatch), not 64-bit bugs. configure accepted the triple unaided
([`build/rts622/FINDINGS.md`](../build/rts622/FINDINGS.md)). The 64-bit problems that did surface were in the
toolchain, not the source: `-fwrapv` and `-std=gnu89` on every `.hc` compile
([D48](../DECISIONS.md#d48--a-compiled-haskell-program-runs-putstrln-hello-works-on-622)), and the `HTYPE_*` block that gcc 16 stops configure from producing
([D47](../DECISIONS.md#d47--the-compiler-links-runs-and-compiles-base-137143-modules-to-hc)).

**One edit came late.** `main/GetImports.hs` reads source through a text
handle. Under the MicroHs runtime that decodes UTF-8 and dies on `Ctype.lhs`.
The `__MHS__` branch was made during stage 2 ([D49](../DECISIONS.md#d49--stage-2-begun-the-mhs-built-ghc-compiles-its-own-source-interrupted),
[`notes/phase4/FINDINGS.md`](../notes/phase4/FINDINGS.md#8-addendum-2026-09-15-the-series-is-one-hunk-behind-the-tree) section 8) and is the last hunk of
`0026-runtime-wraps-and-driver-exit.patch`.

[`notes/phase4/FINDINGS.md`](../notes/phase4/FINDINGS.md#4-the-patch-series) section 4 has the per-patch table and the tooling
that derives the series from the tree.

## Without Nix

This is the chain as I first built it, before Nix. The scripts under `build/` and
`notes/` find the checkout through `GHC_BOOTSTRAP_ROOT`, which `mise.toml`
sets. Run them under mise (`mise exec -- sh build/...`). The scripts in this
directory find the repository from their own location.

The compiler tree, from the pristine `ghc-6.2.2-src.tar.bz2`:

```sh
sh ghc622/reproduce-6.2.2.sh            # -> build/repro-622/ghc, 3-4 minutes
```

The script does the following:
- applies the 26 patches;
- runs GHC's own configure and `config.h` rule;
- makes `DerivedConstants.h` from `mkDerivedConstants.c` with the
  unregisterised flags, and the `HTYPE_*` block;
- regenerates the three parsers and ten primop tables with the chain's happy
  and an mhs-built genprimopcode;
- decodes the alex lexer's tables into boxed arrays.

The result is checked against the working tree with `diff -r`. The series is
derived from the working tree, not the other way round: `make-patch.sh`
regenerates it and fails on any hunk it cannot classify.
[`notes/phase4/FINDINGS.md`](../notes/phase4/FINDINGS.md) records the provenance of every input, including
the ones the script does not produce (the shims, the boot files, `Config.hs`).

Typechecking the tree with mhs takes about an hour
([`notes/phase4/FINDINGS.md`](../notes/phase4/FINDINGS.md#2-what-reproduce-622sh-does) section 2):

```sh
TMPDIR=build/repro-622/tmp EXTRA_SHIMS=$PWD/ghc622/shims \
  sh ghc622/tools/probe-ordered.sh <label> build/repro-622/ghc/compiler \
     build/repro-622/ghc/includes build/repro-622/order-6.2.2.txt \
     ghc622/hsboot build/repro-622/gen
```

From the typechecked tree to the fixed point, the chain is one dependency
graph, `build/Makefile` (see the [build/ README](../build/README.md)):

```sh
make -f build/Makefile -j4 test3            # stage 1, base, haskell98, stages 2 and 3
make -f build/Makefile -j4 stage5           # stages 4 and 5
make -f build/Makefile compare4 compare5    # the fixed-point checks
make -f build/Makefile status               # what is stale, one line per phase
```

Use `-j4`, because each GHC compile may use up to 8 GB of address space.
`make -j4 test` took 58 minutes on 2026-09-16 (16 cores).

## What does not work

As of 2026-09-23, these are the things I know are not right:

1. **The fixed point is exact for the Abstract C, not for the binaries.**
   `ghc-stage3` and `ghc-stage4` differ in 38 bytes: the GNU build-id note and
   two objects.
   - `utils/Pretty` has an uninitialised upper word in a `Float` literal.
     `PprAbsC.floatToWord` reads a 4-byte float back as an 8-byte word, a 6.2.2
     defect on 64-bit. I left it unpatched in the pristine stage-2 source.
   - `coreSyn/CoreUtils` has one SRT with two entries swapped. Unique order
     follows evaluation order, and stage 1 compiled 25 modules with
     `-fno-strictness`.

   Neither difference propagates: stage 5 equals stage 4 in all 220 `.hc`
   files ([D51](../DECISIONS.md#d51--stage-3-and-stage-4-the-native-compiler-rebuilds-itself-218-of-220-modules-byte-identical)).
2. **The reproduction without Nix depends on the host's headers.**
   `reproduce-6.2.2.sh` applies all 26 patches exactly. On a machine whose
   kernel headers define `EFTYPE` it writes `CONST_EFTYPE 134` where the
   reference tree has `-1` ([`notes/phase4/FINDINGS.md`](../notes/phase4/FINDINGS.md#3-verification) section 3).
3. **Nine compiler modules do not typecheck under mhs**, none of them on
   `Main`'s path ([D46](../DECISIONS.md#d46--the-622-probe-passes-main-typechecks-226235)):
   - `PrimPacked`, which the FastString shim shadows;
   - five GHCi bytecode modules plus `InteractiveUI` (`GHC.Ptr`; GHCi is off);
   - the dead `IlxGen` and `JavaGen` back ends.
4. **6.2.2's own limits on x86-64** ([`build/research-6.2-x86_64.md`](../build/research-6.2-x86_64.md)):
   - `foreign import "wrapper"` adjustors are not supported.
   - 6.2.2's `HEAP_ALLOCED` keyed a 4096-entry map on the low 32 bits of an
     address, and under ASLR the heap aliased static data in about 0.6% of
     processes. RTS patch 0003 replaces the map with a fixed heap base and a
     64 GB window, so a program's heap cannot grow past 64 GB ([D50](../DECISIONS.md#d50--rts-patch-0003-the-megablock-map-gets-a-fixed-base-and-a-window)).
5. **Hygiene.**
   - The RTS is compiled without `-fwrapv`. I haven't traced any failure to it.
   - Three shim modules (`FastString`, `Foreign`, `StringBuffer`) exist in
     both `shims-ghc` and `shims`, with different contents. `shims` comes
     first on the `-i` path.
