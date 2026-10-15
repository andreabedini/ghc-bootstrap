# GHC 6.10.4

Built by the chain's [GHC 6.6](../ghc66/README.md) with its own
`configure && make`: unregisterised via C, no GHCi, no native code generator,
no profiling, as 6.6 was. It builds [GHC 6.12.3](../ghc612/README.md).

```sh
nix-build -A ghc610
```

6.10.4 is the newest release whose configure accepts a 6.6 as the
bootstrapping compiler. It asks for 6.4 or later; 6.12 asks for 6.8.

## Notes

- **Parsers and lexers** are regenerated from their grammars
  (`common/regen-parsers.sh`) with 6.6's happy 1.16 and alex 2.1.0.
- **`build.mk`** is written in the derivation; for 6.6 it was part of the
  patch. It turns
  the ways and the interpreter off, and sets the C flags a 2026 gcc needs for
  2009 C: `-std=gnu89 -fpermissive -w`, plus `-fwrapv` for the generated C.
  These flags reach every compile.
- **libffi gets a plain `ar`.** configure makes `AR` into `ar q`, and libffi's
  libtool then runs `ar q cru`.
- **GMP 6.1.2** ([gmp612](../gmp612/README.md), [D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)). **Non-PIE** through the
  cc wrapper.
- **Test:** `common/test/T3.hs`, compiled by the installed compiler.

`default.nix` is the only file.
