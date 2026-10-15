# common

Files that several links of the chain share.

| Path | What it is | Used by |
|---|---|---|
| `shims/` | the ghc-on-mhs shims: modules from GHC's libraries and from mtl (`Data.Map`, `Data.Array.*`, `Control.Monad.Reader`, ...) written over MicroHs's library | [happy](../happy/README.md), [GHC 6.2.2](../ghc622/README.md) stage 1 |
| `regen-parsers.sh` | puts a tarball's generated parsers and lexers back under their grammars (GHC ships these as `<name>.source` from 6.10 on), so that the tarball's own build rules regenerate them with the chain's happy and alex | every GHC from 6.10.4 on |
| `cmp-regenerated.sh` | after the build, compares each regenerated parser and lexer with the shipped one: strictly when the chain's happy is the version that made it, as a report otherwise | the same GHCs |
| `hadrian-ghc.nix` | a GHC built with Hadrian: Hadrian bootstrapped by `bootstrap.py` from a plan whose Hackage tarballs Nix fetches, then `install` | [9.8.4](../ghc98/README.md), [9.12.4](../ghc912/README.md), [9.14.1](../ghc914/README.md) |
| `test/T3.hs`, `test/T3.out` | the install check for 6.10 and later: sorting, `Data.Map`, Integer through GMP, Int bounds, Double show/read/round, a caught divide by zero | every GHC from 6.10.4 on |
| `test/GmpZero.hs` | the regression test for GMP 6.2's lazy `mpz_init` and pre-8.0 Integers ([D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)) | [gmp612](../gmp612/README.md) |
