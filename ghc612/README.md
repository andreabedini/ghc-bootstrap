# GHC 6.12.3

Built by the chain's [GHC 6.10.4](../ghc610/README.md) with its own
`configure && make` (the first release of the `ghc.mk` build system): no GHCi,
one library way. It builds [GHC 7.4.2](../ghc74/README.md).

```sh
nix-build -A ghc612
```

## Notes

- **The first registerised GHC in the chain.** 6.12.3 is built registerised, with the
  x86-64 native code generator, even though the 6.10.4 that boots it is
  unregisterised. `GhcUnregisterised` describes the compiler being built.
  Stage 1 is whatever the boot compiler can produce, and everything stage 1
  compiles is native code ([D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)). `registerised = false` gives the via-C
  variant.
- **`Rts.h`'s `#if __GNUC__ > 4` blocks** were written for a gcc that did not
  exist in 2010. One of them defines macros as `#pragma GCC visibility ...`,
  which no cpp accepts. The derivation takes the branch every 2010 gcc took.
- **Parsers and lexers** are regenerated from their grammars with 6.6's
  happy 1.16 and alex 2.1.0 (`common/regen-parsers.sh`).
- **`build.mk`** as for 6.10, in the new build system's names.
- **GMP 6.1.2** ([gmp612](../gmp612/README.md), [D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)). **Non-PIE** through the
  cc wrapper.
- **Test:** `common/test/T3.hs`.

`default.nix` is the only file.
