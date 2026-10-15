# GHC 6.6

Built by the chain's [GHC 6.2.2](../ghc622/README.md) with 6.6's own
`configure && make`: unregisterised via C, no GHCi, no native code generator,
no profiling. It builds [GHC 6.10.4](../ghc610/README.md).

```sh
nix-build -A ghc66           # GHC 6.6
nix-build -A ghc66.happy116  # happy 1.16, compiled by 6.2.2
nix-build -A ghc66.alex210   # alex 2.1.0, compiled by 6.2.2
```

## Files

| File | What it is |
|---|---|
| `default.nix` | the scope: the compiler and its two generators |
| `ghc.nix` | GHC 6.6: configure, make, make install, then `test/T2.hs` through the installed compiler |
| `ghc-6.6-by-622.patch` | four edits: configure's perl version check, `-threaded` only with GHCi (`compiler/Makefile.ghcbin`), the RTS's `cc-options` (`-std=gnu89`), and a `mk/build.mk` |
| `happy116.nix` | happy 1.16, with no parser from its tarball: generation 1 from the chain's happy 1.19.5, generation 2 by generation 1, then a fixed point |
| `alex210.nix` | alex 2.1.0; its lexer `Scan.hs` can only come from an alex, so the tarball's is the seed, discharged by a fixed point |
| `cpp-template.sh` | the templates' cpp step from `Setup.lhs`, without its line-marker bug |
| `cmp-generated.sh` | compares a regenerated parser or lexer with the shipped one, modulo blank lines and LINE pragmas |
| `shims622/Data/Version.hs` | the one module happy and alex need that 6.2.2's base lacks |
| `test/T2.hs` | the test program |

## Notes

- **None of the tarball's generated parsers and lexers is used.** The seven
  files are deleted after unpacking, and 6.6's own Makefile rules regenerate
  them with happy 1.16 and alex 2.1.0, the versions that made the shipped
  ones. After the build, each regenerated file must equal the shipped one.
- **GMP 6.1.2** ([gmp612](../gmp612/README.md), [D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)).
- **Non-PIE.** Every gcc call goes through the cc wrapper, which adds
  `-fno-pie`/`-no-pie`.
- My working notes from building 6.6 by hand, before the derivation existed, are in
  [`build/ghc66-by-622/NOTES.md`](../build/ghc66-by-622/NOTES.md).
