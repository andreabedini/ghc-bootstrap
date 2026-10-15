# GHC 9.4.8

Built by the chain's [GHC 9.0.2](../ghc90/README.md) with `configure && make`:
registerised with the native code generator, GHCi, SMP, static only. It builds
[GHC 9.8.4](../ghc98/README.md). 9.4.8 asks for 9.0 or later; 9.2 is skipped.

```sh
nix-build -A ghc94           # GHC 9.4.8
nix-build -A ghc94.happy120  # happy 1.20.1.1, compiled by 9.0.2
```

## Files

| File | What it is |
|---|---|
| `default.nix` | the scope: the compiler and happy 1.20.1.1 |
| `ghc.nix` | GHC 9.4.8 |
| `happy120.nix` | happy 1.20.1.1, the version 9.4 and 9.8 ask for. Its parsers are regenerated from the release tag's grammars by the chain's happy 1.19.5, then taken to a fixed point |

## Notes

- **The last GHC built with make.** 9.4 is the last release that carries the
  make build system, and it keeps it only for a boot compiler older than 9.1.
  A 9.0.2 is one. nixpkgs 23.11 and Guix both build 9.4 this way.
- **happy and alex are required** even though the tarball ships every
  generated parser and lexer. The compiler, genprimopcode and hpc declare
  `build-tool-depends: alex >= 3.2.6, happy >= 1.20.0`, and ghc-cabal refuses
  to configure them without the programs. They are happy 1.20.1.1 (here) and
  7.4.2's alex 3.2.7.4. Both also regenerate the parsers and lexers, and
  Cabal's lexer.
- The same StgCRunAsm patch as [9.0.2](../ghc90/README.md) (read from
  `ghc90/`), and the same `--with-gmp-*` flags.
- **Non-PIE** through the cc wrapper. **Test:** `common/test/T3.hs`.
