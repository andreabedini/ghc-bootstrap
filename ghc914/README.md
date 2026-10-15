# GHC 9.14.1

The top of the chain: the newest GHC release at the time of writing, built by
the chain's [GHC 9.12.4](../ghc912/README.md) with Hadrian
(`common/hadrian-ghc.nix`).

```sh
nix-build -A ghc914
```

## Files

| File | What it is |
|---|---|
| `default.nix` | the derivation, through `common/hadrian-ghc.nix` |
| `plan-bootstrap-9_12_2.json` | the tarball's bootstrap plan, copied verbatim. The derivation rewrites its boot-library versions to the 9.12.4's |
| `ghci-Binary-HalfWord-9.12.3-boot.patch` | the one-line guard from the ghc-9.14 branch |

## Notes

- **The real boot floor is 9.10, not 9.6.** 9.14.1's `configure.ac` still says
  a 9.6 will do, and with a 9.8.4 Hadrian bootstraps and configure passes. Then
  stage 0 fails configuring ghci. It wants `ghc-internal >= 9.1001.0` and
  `ghc-heap >= 9.10.1` from the boot compiler, and ghc-internal exists from
  9.10 on. The tarball's bootstrap plans are for 9.10 and 9.12 boots only.
- **The HalfWord patch.** 9.14.1 defines `Binary HalfWord` only under
  `#if MIN_VERSION_ghc_internal(9,1400,0)`, on the assumption that the
  `HalfWord` newtype is 9.14's. But 9.12.3 backported the newtype to
  ghc-heap. A 9.12.3 or 9.12.4 boot compiler therefore has the newtype and no
  instance, and stage 0 of ghci fails with "Could not deduce Binary
  Heap.HalfWord". The ghc-9.14 branch uses
  `MIN_VERSION_GLASGOW_HASKELL(9,12,2,20250919)` instead.
- **GMP:** from 9.14 the GMP backend lives in ghc-internal, which records
  `--with-gmp-libraries` in its library-dirs.
- nixpkgs boots 9.14.1 from a 9.10.3 binary distribution. None of nixpkgs'
  9.14.1 patches is for x86-64 Linux with glibc.
