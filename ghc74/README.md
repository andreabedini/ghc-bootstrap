# GHC 7.4.2

Built by the chain's [GHC 6.12.3](../ghc612/README.md) with `configure && make`:
registerised with the native code generator, no GHCi, one library way. It
builds [GHC 7.8.4](../ghc78/README.md). It also builds the happy and alex that
the later GHCs need. 7.4.2 asks for 6.12 or later, so 7.0 and 7.2 are
skipped.

```sh
nix-build -A ghc74            # GHC 7.4.2
nix-build -A ghc74.mtl        # mtl 1.1.1.1 from 7.4.2's own tarball
nix-build -A ghc74.happy1195  # happy 1.19.5, compiled by 7.4.2
nix-build -A ghc74.alex327    # alex 3.2.7.4, compiled by 7.4.2
```

## Files

| File | What it is |
|---|---|
| `default.nix` | the scope: the compiler and the three packages below |
| `ghc.nix` | GHC 7.4.2 |
| `mtl.nix` | mtl 1.1.1.1 from 7.4.2's tree. 7.4.2 builds it but never installs it, and happy 1.19.5 needs it |
| `happy1195.nix` | happy 1.19.5, regenerated from its grammars, taken to a fixed point, and compared with the parsers the tarball ships. It serves 7.8.4 to 8.8.4 |
| `alex327.nix` | alex 3.2.7.4; its lexer `Scan.hs` is the tarball's, discharged by a fixed point. It serves every GHC from 7.8.4 to 9.14.1 |

## Notes

- **Why these generator versions.** happy 1.19.5 is the newest happy 7.4.2's
  libraries can build: 1.19.6 and later want an mtl with
  `Control.Monad.Except`. It is also the happy that made 8.0.2's shipped
  parsers. No alex 3.1.x can stand in for 3.2.7.4, because their executable
  imports QuickCheck, which 7.4.2 does not have.
- **The tarball ships build products.** `utils/ghc-pwd/dist-boot` holds a
  `ghc-pwd` binary and its `.o` and `.hi`. configure rebuilds them anyway, and
  the derivation deletes them before anything runs.
- **C flags:** `-std=gnu89 -fpermissive -fwrapv`. **GMP 6.1.2**
  ([gmp612](../gmp612/README.md), [D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)). **Non-PIE** through the cc wrapper.
- **Parsers and lexers** of 7.4.2 itself are regenerated with 6.6's happy 1.16
  and alex 2.1.0.
- **Test:** `common/test/T3.hs`.
