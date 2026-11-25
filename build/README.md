# build

The GHC 6.2.2 chain without Nix: a Makefile and the scripts it runs. The Nix
build ([`ghc622/`](../ghc622/README.md)) reads none of it. It runs on MicroHs
0.16.8.0 (`MicroHs/bin/mhs`, see [`SOURCES.md`](../SOURCES.md#microhs)).

Only the scripts and the tables they read are tracked. The trees, objects
and binaries the scripts produce (`ghc-6.2.2-run1/ghc`, `ghc622-mhs/ghc`,
`rts622/ghc-6.2.2`, `repro-622/`, ...) are ignored and appear once the
scripts run. The scripts find the checkout through `GHC_BOOTSTRAP_ROOT`; run
them with `mise exec -- sh build/...`. The [ghc622 README](../ghc622/README.md#without-nix)
gives the order to run them in.

## Files at the top

| File | What it is |
|---|---|
| `Makefile` | the 6.2.2 chain from stage 1 to stage 5 as one dependency graph; its header lists the targets (`stage1`, `deps`, `base`, `haskell98`, `stage2`, `test`, `stage3`, `test3`, `stage4`, `stage5`, `compare3`-`compare5`, `status`) |
| `build-happy-mhs.sh`, `link-happy.sh` | happy 1.19.5 compiled by mhs with the ghc-on-mhs shims |
| `fixpoint-happy.sh` | happy's own parsers taken to a fixed point ([D7](../DECISIONS.md#d7--happys-seed-is-a-ghc-built-happys-output-discharged-twice), [D14](../DECISIONS.md#d14--happy-is-verified-by-regeneration-not-by-equality-with-a-ghc-built-happy)); generation 2 is `happy/happy-seed/` |
| `ddc-happy115.sh` | the diverse double compilation of happy's seed from happy 1.15 ([D56](../DECISIONS.md#d56--happys-seed-by-diverse-double-compilation-from-happy-115)) |
| `order-6.2.2.txt` | the module order of 6.2.2's compiler, which `ghc622/reproduce-6.2.2.sh` checks its own against |

## Directories

| Directory | What it holds |
|---|---|
| `mk/` | the Makefile's per-module recipes (`compile-stage2.sh` with its retry ladder of `-O`, `-fno-strictness`, `-O0`; `compile-base.sh`, `compile-h98.sh`), the `.hi` format check, and `gen-deps.py`, which writes the per-module rules |
| `ghc-6.2.2-run1/` | where the compiler tree that mhs compiles lives (ignored); `ghc622/reproduce-6.2.2.sh` reproduces it |
| `gen622/` | 6.2.2's generated sources (three parsers, ten primop tables) regenerated with the chain's tools only (`regen.sh`) |
| `lexer622/` | a token-dump driver for 6.2.2's converted alex lexer (`driver/Main.hs`) |
| `rts622/` | 6.2.2's runtime system compiled unregisterised on x86-64 without a GHC (`build-rts.sh`, `apply-fixes.pl`, `genapply/`), test mains, and the heap-alias test behind RTS patch 0003 (`alias-test/`, [D50](../DECISIONS.md#d50--the-rtss-megablock-map-gets-a-fixed-base-and-a-window)) |
| `ghc622-mhs/` | **stage 1**: 6.2.2's compiler linked by mhs (`build.sh`); `base` compiled by it (`run-base.sh`, `build-hc.sh`, `build-cbits.sh`, `build-libbase.sh`, results in `base-results*.tsv`); one program compiled and linked (`link.sh`); the 12 test programs in `test/`; the stage's `topdir/`; `diag/`, the scripts that rebuild `base` and scan its interfaces for colliding uniques |
| `hsc2hs-mhs/` | 6.2.2's `hsc2hs` built with mhs, and the four `.hsc` modules of base it processes (`build.sh`, `build-hc-hsc.sh`, the `hsc2hs` wrapper) |
| `ghc622-stage2/` | **stages 2 to 5**: the native compilers, compiled module by module and linked against `rts622`, and the comparisons that check the fixed point ([D51](../DECISIONS.md#d51--the-622-fixed-point-stage-5-equals-stage-4-in-all-220-modules)) |
| `ghc66-by-622/` | GHC 6.6 built by the chain's 6.2.2 (`build-66.sh`). `ghc622-inst/bin/` holds the wrappers that make stage 3 look installed; they name absolute paths on the machine that ran them |
