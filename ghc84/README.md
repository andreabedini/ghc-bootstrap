# GHC 8.4.4

Built by the chain's [GHC 8.0.2](../ghc80/README.md) with `configure && make`:
registerised with the native code generator, no GHCi, static only. It builds
[GHC 8.8.4](../ghc88/README.md). 8.4.4 asks for 8.0 or later; 8.2 is skipped.

```sh
nix-build -A ghc84
```

## Notes

- **Parsers and lexers** are regenerated with 7.4.2's happy 1.19.5 and alex
  3.2.7.4, and so is Cabal's lexer (`boot/Lexer.x`).
- **`CC=gcc`.** **Non-PIE** through the cc wrapper.
- **Test:** `common/test/T3.hs`.

`default.nix` is the only file.
