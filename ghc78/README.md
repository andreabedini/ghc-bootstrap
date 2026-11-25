# GHC 7.8.4

Built by the chain's [GHC 7.4.2](../ghc74/README.md) with `configure && make`:
registerised with the native code generator, no GHCi, static only. It builds
[GHC 8.0.2](../ghc80/README.md). 7.8.4 asks for 7.4 or later; 7.6 is skipped.

```sh
nix-build -A ghc78
```

## Notes

- **Static only.** 7.8 is the first release that builds dynamic libraries and a
  dynamically linked `ghc` by default. `DYNAMIC_* = NO` keeps the build like
  the earlier GHCs'.
- **Parsers and lexers** are regenerated from their grammars with 7.4.2's
  happy 1.19.5 and alex 3.2.7.4 (`common/regen-parsers.sh`).
- libffi is the 3.0.11 the tarball ships, not the host's.
- **The last GHC on GMP 6.1.2** ([gmp612](../gmp612/README.md), [D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-every-ghc-before-80-gets-gmp-612)).
  **Non-PIE** through the cc wrapper.
- **Test:** `common/test/T3.hs`.

`default.nix` is the only file.
