# MicroHs

MicroHs 0.16.8.0 (`mhs`), bootstrapped from [Hugs](../hugs/README.md) without
any of the pre-generated C it ships. It is the Haskell compiler that builds
cpphs, happy, hsc2hs and GHC 6.2.2's compiler proper.

```sh
nix-build -A mhs
```

## How it is built

1. **Generation 1:** Hugs interprets the MicroHs compiler, which emits C for
   itself (`generated/hmhs.c`, then `bin/hmhs`).
2. **Generation 2:** `hmhs` compiles the same source. This is `bin/mhs`.
3. **Generation 3:** `bin/mhs` compiles the same source again, and the check
   phase requires it to be byte-identical to generation 2.

The derivation deletes MicroHs's shipped `generated/*.c` before anything runs.
The check phase also requires `bin/mhs`, run with `-z` as MicroHs's Makefile
runs it, to reproduce the shipped `generated/mhs.c` byte for byte. It does, so
the seed upstream ships is exactly what the Hugs-derived compiler emits ([D1](../DECISIONS.md#d1--the-seed-is-c-compiler--hugs-source-not-microhss-shipped-comb)).
The shipped C was never wrong; it just wasn't source.

The output is the source tree with `bin/` in it; `mhs` runs in place and finds
`lib/` and `src/runtime/` next to `bin/`.

## Files

| File | What it is |
|---|---|
| `default.nix` | the derivation |
| `bootstrap-seed.sh` | the same chain without Nix: Hugs, generations 1 to 3, and the comparison with the shipped C |
| `patches/0001-microhs-hugs-shim.patch` | a `Data.Version` shim for MicroHs's Hugs override tree, because Hugs's `Data.Version` predates `makeVersion` |

The findings are in [`notes/phase0/FINDINGS.md`](../notes/phase0/FINDINGS.md).
