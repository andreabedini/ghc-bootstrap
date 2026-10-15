# GHC 9.12.4

Built by the chain's [GHC 9.8.4](../ghc98/README.md) with Hadrian
(`common/hadrian-ghc.nix`). It builds [GHC 9.14.1](../ghc914/README.md). 9.12.4
asks for 9.6 or later.

```sh
nix-build -A ghc912
```

## Files

| File | What it is |
|---|---|
| `default.nix` | the derivation, through `common/hadrian-ghc.nix` |
| `plan-bootstrap-9_8_4.json` | the tarball's bootstrap plan for exactly a 9.8.4 boot compiler, copied verbatim |

## Notes

- **Why 9.12.4 is in the chain.** I first tried 9.8.4 -> 9.14.1 directly. 9.14.1's
  configure accepts a 9.6, but its stage-0
  GHCi needs the boot compiler's ghc-internal, which exists from 9.10 on. So
  9.12.4 sits between 9.8.4 and 9.14.1.
- **No patches.** Of the patches nixpkgs applies to 9.12.4, none is for x86-64
  Linux with glibc.
- **`LANG=C.UTF-8`.** 9.12.4's `Parser.y` has non-ASCII text, and happy 1.20
  reads its input in the locale's encoding, which is ASCII in the build
  sandbox. The variable is set here, not in `common/hadrian-ghc.nix`, so that
  9.8.4's derivation stays the same.
