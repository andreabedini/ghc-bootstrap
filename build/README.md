# build

The working tree of the 6.2.2 chain as I first built it by hand, before the Nix
derivations existed. The Nix build ([`ghc622/`](../ghc622/README.md)) reads
none of it. Most of the logs and findings here are Claude's running notes from
those sessions; I kept them because [`DECISIONS.md`](../DECISIONS.md) cites them as evidence.

Only the scripts, findings and result tables are tracked. The trees, objects
and binaries the scripts produce (`ghc-6.2.2-run1/ghc`, `ghc622-mhs/ghc`,
`rts622/ghc-6.2.2`, `repro-622/`, ...) are ignored and appear once the
scripts run. The scripts find the checkout through `GHC_BOOTSTRAP_ROOT`; run
them with `mise exec -- sh build/...`.

Some notes name files that are no longer here. The whole-tree diffs
(`6.2.2-run1.patch`, `6.0-run2.patch`, `rebase622/6.0-current.patch`) and the
old probe tables were removed; `6.2.2-run1.patch` lives on as the series in
`ghc622/patches/`. `convert-lexer.py`, `gen-htypes.c`, `hidict.py` and
`genprimopcode-Main.hs.patch` moved to `ghc622/tools/`. The [ghc622 README](../ghc622/README.md#without-nix)
gives the order to run them in.

## Files at the top

| File | What it is |
|---|---|
| `Makefile` | the 6.2.2 chain from stage 1 to stage 5 as one dependency graph; its header lists the targets (`stage1`, `base`, `haskell98`, `stage2`, `stage3`, `stage4`, `stage5`, `compare3`-`compare5`, `status`) |
| `build-happy-mhs.sh`, `link-happy.sh` | happy 1.19.5 compiled by mhs with the ghc-on-mhs shims |
| `fixpoint-happy.sh` | happy's own parsers taken to a fixed point, which discharged the GHC-built happy ([D7](../DECISIONS.md#d7--use-the-machines-ghc-9141-as-a-one-time-generator-then-discharge-it), [D14](../DECISIONS.md#d14--verify-happy-by-generation-not-by-equality-with-happy-ghc)); generation 2 is `happy/happy-seed/` |
| `order-6.2.2.txt`, `order-6.2.2-pass2.txt`, `order-run4.txt`, `order-side1.txt` ... `order-side3.txt` | module orders for the probes of 6.2.2's compiler under mhs |
| `probe-6.2.2-run1-*.tsv`, `probe-side*.tsv` | the probe results, one row per module (`OK`/`FAIL`, module, message): 226/235 in `probe-6.2.2-run1-final.tsv` ([D46](../DECISIONS.md#d46--the-622-probe-passes-main-typechecks-226235)) |
| [`research-6.2-x86_64.md`](research-6.2-x86_64.md) | whether GHC 6.2.2 was ever a working x86-64 compiler (yes, unregisterised via C), and its known limits there |

## Directories

| Directory | What it holds |
|---|---|
| `mk/` | the Makefile's per-module recipes (`compile-stage2.sh` with its retry ladder of `-O`, `-fno-strictness`, `-O0`; `compile-base.sh`, `compile-h98.sh`), the `.hi` format check, and `gen-deps.py`, which writes the per-module rules |
| `rebase622/` | the dry-run estimate of moving the 6.0 work onto 6.2.2, the measurements behind [D45](../DECISIONS.md#d45--d44-overturned-the-entry-point-moves-to-ghc-622) ([`FINDINGS.md`](rebase622/FINDINGS.md)), the 6.2.2 build order and its `hs-boot` files |
| `ghc-6.2.2-run1/` | the first typecheck of 6.2.2's compiler tree by mhs: 226 of 235 modules, `Main` included ([`FINDINGS.md`](ghc-6.2.2-run1/FINDINGS.md), [`LOG.md`](ghc-6.2.2-run1/LOG.md) with one line per module). The tree itself is what `ghc622/reproduce-6.2.2.sh` reproduces |
| `gen622/` | 6.2.2's generated sources (three parsers, ten primop tables) regenerated with the chain's tools only (`regen.sh`, [`FINDINGS.md`](gen622/FINDINGS.md)) |
| `lexer622/` | 6.2.2's alex lexer converted to boxed arrays for mhs, checked with a token-dump driver (`driver/Main.hs`, [`FINDINGS.md`](lexer622/FINDINGS.md)) |
| `rts622/` | 6.2.2's runtime system compiled unregisterised on x86-64 without a GHC (`build-rts.sh`, `apply-fixes.pl`, `genapply/`), test mains, and the heap-alias test behind RTS patch 0003 (`alias-test/`, [D50](../DECISIONS.md#d50--rts-patch-0003-the-megablock-map-gets-a-fixed-base-and-a-window)) |
| `ghc622-mhs/` | **stage 1**: 6.2.2's compiler linked by mhs (`build.sh`); `base` compiled by it (`run-base.sh`, `build-hc.sh`, `build-cbits.sh`, `build-libbase.sh`, results in `base-results*.tsv`); one program compiled and linked (`link.sh`); the 12 test programs in `test/`; the stage's `topdir/`. [`FINDINGS.md`](ghc622-mhs/FINDINGS.md) covers stage 1 and base, [`FINDINGS-link.md`](ghc622-mhs/FINDINGS-link.md) the first linked program, [`LOG.md`](ghc622-mhs/LOG.md) the running log |
| `ghc622-mhs/diag/` | the FastString unique collision in the shim that corrupted five interfaces of base: diagnosis, the fix (`faststring-intern.patch`), and the full rebuild of base that followed. `SWITCH-NOTE.txt` in the parent records the switch to the rebuilt tree |
| `hsc2hs-mhs/` | 6.2.2's `hsc2hs` built with mhs, and the four `.hsc` modules of base it processes (`build.sh`, `build-hc-hsc.sh`, the `hsc2hs` wrapper, [`FINDINGS.md`](hsc2hs-mhs/FINDINGS.md)) |
| `ghc622-stage2/` | **stages 2 to 5**: the native compilers, compiled module by module and linked against `rts622`, and the comparisons that show the fixed point ([`LOG.md`](ghc622-stage2/LOG.md), [D49](../DECISIONS.md#d49--stage-2-begun-the-mhs-built-ghc-compiles-its-own-source-interrupted)-[D51](../DECISIONS.md#d51--stage-3-and-stage-4-the-native-compiler-rebuilds-itself-218-of-220-modules-byte-identical)) |
| `ghc66-by-622/` | the first build of GHC 6.6 by the chain's 6.2.2, by hand (`build-66.sh`, [`NOTES.md`](ghc66-by-622/NOTES.md)). `ghc622-inst/bin/` holds the wrappers that made stage 3 look installed; they name absolute paths on the machine that ran them |
| `probe/` | twelve small Haskell programs, each isolating one mhs behaviour met on the way (`unsafeInterleaveIO` memoisation, unboxed literals, `hs-boot` cycles, ...) |
| `shims-6.0/`, `shims-6.0-run2/` | the shims of the GHC 6.0 probes ([D44](../DECISIONS.md#d44--is-ghc-6x-within-mhss-reach-measured-not-estimated)) that differ from `ghc622/shims`; the 6.0 probes in `notes/probes` fall back on `ghc622/shims` for the rest |
