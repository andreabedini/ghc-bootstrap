# GHC 8.0.2

Built by the chain's [GHC 7.8.4](../ghc78/README.md) with `configure && make`:
registerised with the native code generator, no GHCi, static only. It builds
[GHC 8.4.4](../ghc84/README.md). 8.0.2 asks for 7.8 or later; 7.10 is skipped.

```sh
nix-build -A ghc80
```

## Notes

- **The C flags change** to `-std=gnu11 -w`. The 2004-2012 sources and their
  generated C needed `-std=gnu89 -fpermissive -fwrapv`, but integer-gmp's
  C files are C99.
- **The host's GMP from here on.** 8.0's integer-gmp works on limbs itself and
  does not trip over GMP 6.2's lazy `mpz_init` ([D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)).
- **Parsers and lexers** are regenerated with 7.4.2's happy 1.19.5 and alex
  3.2.7.4. happy 1.19.5 made the shipped parsers, so the comparison is strict.
- **A Guix patch I don't apply.** Guix patches `rts/posix/OSMem.c` to fall
  back from `MADV_FREE` to `MADV_DONTNEED` at run time. 8.0.2 already
  tries `MADV_FREE` first, and the fallback only matters on kernels before
  4.5.
- Docs are Sphinx from this release on (`BUILD_SPHINX_*`, `BUILD_MAN`).
  **Non-PIE** through the cc wrapper. **Test:** `common/test/T3.hs`.

`default.nix` is the only file.
