# Sources that are not in this repository

Everything under version control here was written for this project. The
inputs it works on are downloaded, and `.gitignore` keeps them out; this file
says what they are, so a fresh checkout can be completed. Checksums are
`sha256sum` of the files as used.

## Tarballs (repo root)

| file | sha256 | published at |
|---|---|---|
| `ghc-6.2.2-src.tar.bz2` | `a0fe7eb8d447f25fbc616cdbce2bb4e03961a884c2c37969d1e23588b588a852` | `https://downloads.haskell.org/~ghc/6.2.2/ghc-6.2.2-src.tar.bz2` |
| `ghc-6.6-src.tar.bz2` | `79b2a29136d56c8120a526188297603304dc80d3093cda76fde939df7d4dcc7e` | `https://downloads.haskell.org/~ghc/6.6/ghc-6.6-src.tar.bz2` |
| `hugs98-plus-Sep2006.tar.gz` | `aafaca9ca544572ebef70bbe86b5eb0abaa5d7c11c0b766d7db72a46b022bed5` | `https://www.haskell.org/hugs/downloads/2006-09/hugs98-plus-Sep2006.tar.gz` |
| `happy-1.19.5.tar.gz` | `62f03ac11d7b4b9913f212f5aa2eee1087f3b46dc07d799d41e1854ff02843da` | `https://hackage.haskell.org/package/happy-1.19.5/happy-1.19.5.tar.gz` |

Each is read by a script of the chain run without Nix: 6.2.2 by
`ghc622/reproduce-6.2.2.sh` (which also asserts its checksum) and
`ghc622/make-patch.sh`, 6.6 by `build/ghc66-by-622/build-66.sh`, Hugs by
`hugs/build-hugs.sh`, happy by `build/build-happy-mhs.sh`. The Nix
derivations fetch their own copies (below).

## `MicroHs/`

An extraction of `MicroHs-0.16.8.0.tar.gz`, the latest release
(`https://github.com/augustss/MicroHs/archive/refs/tags/v0.16.8.0.tar.gz`,
sha256 `7b014251b6dfc332b16a49457797c8f1b32d88633dff5b550132cee8558492f7`,
kept in the repo root), with `mhs/patches/0001-microhs-hugs-shim.patch`
applied to its `hugs/` shim tree (six files; `System/Directory.hs` since
2026-10-12, for the `listDirectory` 0.16.8.0's `Main.hs` uses). `mhs/bootstrap-seed.sh`
expects it at `../MicroHs` and builds `MicroHs/bin/mhs` and
`MicroHs/bin/cpphs`, which every later phase uses. `generated/hmhs.c` and
`mhs.conf` inside it are build outputs. The chain was built on commit
`1474221819a29d6c948fb9a04bd70ed1ded4ca71` (`v0.16.5.0-80-g14742218`);
0.16.8.0 is that commit plus 29 more.

## Fetched by the Nix derivations

Not kept in the checkout; `fetchurl` in the derivation named, with the hash
there (SRI `sha256-...` or hex). The GHC tarballs are `downloads.haskell.org/~ghc/<v>/`.

| input | derivation | hash |
|---|---|---|
| `ghc-6.2.2-src.tar.bz2`, `ghc-6.6-src.tar.bz2` | `ghc622/nix/tree.nix`, `ghc66/ghc.nix` | as in the table above |
| `ghc-6.10.4-src.tar.bz2` | `ghc610` | `d66a8e52572f4ff819fe5c4e34c6dd1e84a7763e25c3fadcc222453c0bd8534d` |
| `ghc-6.12.3-src.tar.bz2` | `ghc612` | `sha256-bL2+QVAR8sfRXk2FB1jY05P3Bhe4jLMjfSxgK7YOXmg=` |
| `ghc-7.4.2-src.tar.bz2` | `ghc74` | `sha256-8u4SiaM8xwU5KHEphBrMfq8WESu2DFm1pu6RiHv9g20=` |
| `ghc-7.8.4-src.tar.xz` | `ghc78` | `sha256-wxnNlK2yhBd+0ObSFUbtC5AK2EuGuHwGqZ6sNRUpgsQ=` |
| `ghc-8.0.2-src.tar.xz` | `ghc80` | `sha256-EWJUU+HQaGs/pnOZiPcOysg2ytwwufDItJ75CR1hGLE=` |
| `ghc-8.4.4-src.tar.xz` | `ghc84` | `sha256-ERF3NaWOUHxIHAnz85rloxTp+/SfwxCVKPmep5WQBLI=` |
| `ghc-8.8.4-src.tar.xz` | `ghc88` | `sha256-8FBeOLIjX/nxCQtR9E1sjv03EGjlprtCoqbYtntf/C0=` |
| `ghc-9.0.2-src.tar.xz` | `ghc90` | `sha256-FA5CuWNGMi0aOesXYCvNx24pICitSmkoayMLqxiKkZc=` |
| `ghc-9.4.8-src.tar.xz` | `ghc94` | `sha256-C/QH62f+PjwksPTI3qjLY+B/Y8oPds8gWFZRQ1B6uF4=` |
| `ghc-9.8.4-src.tar.xz` | `ghc98` | `sha256-F+gYjzyKXC9z+0410BAy6NwliDXsh21SyK2O49JLL8U=` |
| `happy-1.20.1.1.tar.gz` (Hackage) | `ghc94/happy120.nix` | in the file |
| `src/Parser.ly`, `src/AttrGrammarParser.ly` at the `1.20.1.1` tag of github.com/haskell/happy (the Hackage tarball ships only the generated parsers) | `ghc94/happy120.nix` | in the file |
| `ghc-9.12.4-src.tar.xz` | `ghc912` | `sha256-AtHuUICs8A4TW5OyOPCQFbBv8nJUzeWWac9XxCwr7kM=` |
| `ghc-9.14.1-src.tar.xz` | `ghc914` | `sha256-KoN3nJr4ZVSjKJ8nh6ONaqg9ANE2qp+SA2HdaTwQHnc=` |
| Hadrian's bootstrap dependencies for a 9.8 boot compiler (26 Hackage tarballs and `.cabal` files: shake 0.19.8, Cabal 3.14.1.1, alex 3.5.2.0, ...) | `ghc912/plan-bootstrap-9_8_4.json`, copied from `ghc-9.12.4/hadrian/bootstrap/`, used by 9.12.4 and 9.14.1 | the plan's `src_sha256` and `cabal_sha256` fields |
| Hadrian's bootstrap dependencies for a 9.12 boot compiler | `ghc914/plan-bootstrap-9_12_2.json`, copied from `ghc-9.14.1/hadrian/bootstrap/` | the plan's `src_sha256` and `cabal_sha256` fields |
| `hp2ps-C-gnu17.patch` (Fedora's copy of GHC !13863, the C23 fix for `utils/hp2ps/Utilities.c`) | `ghc98/hp2ps-C-gnu17.patch` | in the repository |
| Hadrian's 18 bootstrap dependencies (Hackage tarballs and revised `.cabal` files: shake 0.19.8, QuickCheck 2.14.3, ...) | `ghc98/plan-bootstrap-9_4_4.json`, copied from `ghc-9.8.4/hadrian/bootstrap/` | the plan's `src_sha256` and `cabal_sha256` fields |
| `happy-1.16.tar.gz`, `alex-2.1.0.tar.gz` (Hackage) | `ghc66/happy116.nix`, `ghc66/alex210.nix` | in the files |
| `happy-1.19.5.tar.gz` (as above), `alex-3.2.7.4.tar.gz` (Hackage) | `ghc74/happy1195.nix`, `ghc74/alex327.nix` | in the files |
| `libraries/mtl` of `ghc-7.4.2-src.tar.bz2` (mtl 1.1.1.1, which 7.4.2 builds but does not install) | `ghc74/mtl.nix` | the tarball's, above |
| `happy-1.19.12.tar.gz` (Hackage); `src/Parser.ly`, `src/AttrGrammarParser.ly`, `templates/GenericTemplate.hs`, `GLR_Base.hs`, `GLR_Lib.hs` at the `1.19.12` tag of github.com/haskell/happy (the tarball ships only the generated parsers and the preprocessed templates); `gen-happy-sdist/Main.hs` at the same tag (sha256 `2d1b93d621c7a7414de2a447bb9cb92d17e6100e1f03f09e4d7fa17816c1dca8`) read for how the templates are made, not fetched by the build | `ghc88/happy11912.nix` | in the file |
| `gmp-6.1.2.tar.xz` (`ftp.gnu.org/gnu/gmp/`) | `gmp612/default.nix` | `sha256-h7Vl6JqaaE/k6+7duDmdziWZ+ckEmFTKjA373qDiGRI=` |
| `hugs98-plus-Sep2006.tar.gz`, `MicroHs-0.16.8.0`, `cpphs-1.20.9.tar.gz` and `polyparse-1.12.tar.gz` (Hackage) | `hugs/default.nix`, `mhs/default.nix`, `cpphs/default.nix` | in the files |

GMP 6.1.2 is the GMP every compiler before 8.0 links against: GMP 6.2's lazy
`mpz_init` breaks their Integer ([DECISIONS.md](DECISIONS.md) [D52](DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)). The host's GMP serves
8.0 and later. The release tarballs used to pick the chain's GHCs are those whose
`configure.ac` accepts the previous one as the bootstrapping compiler.

## Extractions and outputs

Every `ghc-*` directory under `build/`, `build/ghc66-by-622/{src,src-verify}`,
`build/ghc66-by-622/ghc622-inst/src`, `build/hugs/hugs98-plus-Sep2006`,
`build/repro-622`, `build/rebase622/{ghc-6.2.2,try622}`, `build/happy-1.19.5` and
`build/rts622/ghc-6.2.2` are extractions of the tarballs above, some with a
patch series applied; the series and the scripts that apply them are tracked,
the trees are not. Objects, interfaces, `.hc` files, archives, binaries,
`.mhscache` caches and `tmp/` directories are outputs of tracked scripts.
The tree `build/ghc-6.2.2-run1/ghc` that `ghc622/reproduce-6.2.2.sh` diffs
against is recorded as the `ghc622/patches` series (`ghc622/make-patch.sh`
regenerates it from that tree, generated files excluded).
