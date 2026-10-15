# GHC 8.8.4

Built by the chain's [GHC 8.4.4](../ghc84/README.md) with `configure && make`:
registerised with the native code generator, GHCi, SMP, static only. It builds
[GHC 9.0.2](../ghc90/README.md), and the happy 9.0.2 needs. 8.8.4 asks for
8.4 or later; 8.6 is skipped.

```sh
nix-build -A ghc88             # GHC 8.8.4
nix-build -A ghc88.happy11912  # happy 1.19.12, compiled by 8.8.4
```

## Files

| File | What it is |
|---|---|
| `default.nix` | the scope: the compiler and happy 1.19.12 |
| `ghc.nix` | GHC 8.8.4 |
| `happy11912.nix` | happy 1.19.12, the version 9.0.2 asks for (>= 1.19.10, < 1.20), with none of the generated files its tarball ships. The grammars and templates come from the release tag; the preprocessed templates are remade with the chain's cpphs and must equal the shipped ones byte for byte |

## Notes

- **GHCi and SMP from here on.** This is the standard configuration (nixpkgs,
  Guix), and two upstream facts force it:
  - 8.8.4 does not compile without GHCi: `DynFlags.hs` imports `Ptr` only
    under `#if defined(GHCI)`, but stage 2 needs it either way.
  - An SMP-less threaded RTS rejects `-N` and `-qg`, and 9.8's Hadrian is
    linked with `-with-rtsopts=-I0 -qg`.

  The 6.x to 8.4 builds keep both off, because they only ever compile the next
  GHC.
- **Parsers and lexers** of 8.8.4 itself are regenerated with 7.4.2's happy
  1.19.5 and alex 3.2.7.4, and so is Cabal's lexer.
- **`GHC=`** is passed to configure. **Non-PIE** through the cc wrapper.
  **Test:** `common/test/T3.hs`.
