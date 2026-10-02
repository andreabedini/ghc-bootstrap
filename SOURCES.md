# Sources that are not in this repository

Everything under version control here was written for this project. The
inputs it works on are downloaded, and `.gitignore` keeps them out; this file
says what they are, so a fresh checkout can be completed. Checksums are
`sha256sum` of the files as used.

## Tarballs (repo root)

| file | sha256 | published at |
|---|---|---|
| `ghc-4.08.2-src.tar.bz2` | `38dc3e1ef888013383d205a8991e1d16f44d4e60f58523dde6bb64467cb7242b` | `https://downloads.haskell.org/~ghc/4.08.2/ghc-4.08.2-src.tar.bz2` |
| `ghc-5.00.2-src.tar.bz2` | `b38d7f043657d8ab5c9cd7dbe2103a9e29be208538e518d1528cf66ce0ee84d8` | `https://downloads.haskell.org/~ghc/5.00.2/ghc-5.00.2-src.tar.bz2` |
| `ghc-6.0-src.tar.bz2` | `bb7d5481963b60417a4ea51d015d2ceb7bbefcdac035d6d2df4143e839a2171a` | `https://downloads.haskell.org/~ghc/6.0/ghc-6.0-src.tar.bz2` |
| `ghc-6.2-src.tar.bz2` | `8adfbe3d7c57de75dc7e437f188a8da73af6eff3bc444c5d7c77814016f7e298` | `https://downloads.haskell.org/~ghc/6.2/ghc-6.2-src.tar.bz2` |
| `ghc-6.2.2-src.tar.bz2` | `a0fe7eb8d447f25fbc616cdbce2bb4e03961a884c2c37969d1e23588b588a852` | `https://downloads.haskell.org/~ghc/6.2.2/ghc-6.2.2-src.tar.bz2` |
| `ghc-6.6-src.tar.bz2` | `79b2a29136d56c8120a526188297603304dc80d3093cda76fde939df7d4dcc7e` | `https://downloads.haskell.org/~ghc/6.6/ghc-6.6-src.tar.bz2` |
| `ghc-6.6.1-src.tar.bz2` | `489126ceeb2dbb6a85ef8d87d6792e61e1bc0d5882e4b33a7725410d796132c6` | `https://downloads.haskell.org/~ghc/6.6.1/ghc-6.6.1-src.tar.bz2` |
| `ghc-6.10.4-src.tar.bz2` | `d66a8e52572f4ff819fe5c4e34c6dd1e84a7763e25c3fadcc222453c0bd8534d` | `https://downloads.haskell.org/~ghc/6.10.4/ghc-6.10.4-src.tar.bz2` |
| `hugs98-plus-Sep2006.tar.gz` | `aafaca9ca544572ebef70bbe86b5eb0abaa5d7c11c0b766d7db72a46b022bed5` | `https://www.haskell.org/hugs/downloads/2006-09/hugs98-plus-Sep2006.tar.gz` |

The 6.2.2 tarball's checksum is also asserted by `phase4/reproduce-6.2.2.sh`.
The chain uses 4.08.2 (phases 2-3) and 6.2.2 (phase 4); 5.00.2, 6.0 and
6.10.4 were candidates measured in phase 1 and D44, and 6.2 was fetched
alongside 6.2.2 and never opened. 6.6 is the next rung: `build/ghc66-by-622`
builds it with the chain's 6.2.2 (2026-09-25); 6.6.1 was fetched as a
fallback and never opened.

## `MicroHs/`

A clone of `https://github.com/augustss/MicroHS.git` at commit
`1474221819a29d6c948fb9a04bd70ed1ded4ca71` (`v0.16.5.0-80-g14742218`), with
`phase0/patches/0001-microhs-hugs-shim.patch` applied to its `hugs/` shim
tree (five files; the working-tree diff against that commit is identical to
the patch). `phase0/bootstrap-seed.sh` expects it at `../MicroHs` and builds
`MicroHs/bin/mhs` and `MicroHs/bin/cpphs`, which every later phase uses.
`generated/hmhs.c` and `mhs.conf` inside it are build outputs.

## `nhc98/`

A clone of a local mirror (`../haskell-implementations/nhc98.git`, commit
`f88aaa63934e196a58af832c4a1a73dade1517ad`, "Import from 1.22"). Consulted
for `BOOTSTRAP-ANALYSIS.md` only; nothing in the chain uses it.

## `build/downloads/`

The happy release tarballs surveyed for the happy sub-bootstrap (D4-D10):

- `happy-1.15.tar.gz` `01d12df18d9dde02e2c85595df58d9aa000e04dd343c02a023def3ffd1fa3c7e`
- `happy-1.16.tar.gz` `4da47f4904dbdddfb58140edb0395383feba72dfc77759e57587a526dd9496c5`
- `happy-1.17.tar.gz` `dca4e47d17e5d538335496236b3d2c3cbff644cf7380c987a4714e7784c70a2b`
- `happy-1.18.10.tar.gz` `c1c920f77906740252e261e2baec5b7519e584344d6080aa5a9cc0b677b9064b`
- `happy-1.18.4.tar.gz` `909bec4541a92d3765e74756f752514d2d03ec7a5d3e74c18268a57fe7ffa832`
- `happy-1.19.0.tar.gz` `df1cc00dee75681e6bf8c94c44e84fe9505a660cb2533d9a26f1879c192113de`
- `happy-1.19.5.tar.gz` `62f03ac11d7b4b9913f212f5aa2eee1087f3b46dc07d799d41e1854ff02843da`

From Hackage (`https://hackage.haskell.org/package/happy-<version>/happy-<version>.tar.gz`).
Only 1.19.5 is built (`build/build-happy-mhs.sh`); the extraction next to
the tarballs is scratch.

## Fetched by the Nix derivations

Not kept in the checkout; `fetchurl` in the derivation named, with the hash
there (SRI `sha256-...` or hex). The GHC tarballs are `downloads.haskell.org/~ghc/<v>/`.

| input | derivation | hash |
|---|---|---|
| `ghc-6.2.2-src.tar.bz2`, `ghc-6.6-src.tar.bz2`, `ghc-6.10.4-src.tar.bz2` | `nix/ghc622/tree.nix`, `nix/ghc66/ghc.nix`, `nix/ghc610` | as in the table above |
| `ghc-6.12.3-src.tar.bz2` | `nix/ghc612` | `sha256-bL2+QVAR8sfRXk2FB1jY05P3Bhe4jLMjfSxgK7YOXmg=` |
| `ghc-7.4.2-src.tar.bz2` | `nix/ghc74` | `sha256-8u4SiaM8xwU5KHEphBrMfq8WESu2DFm1pu6RiHv9g20=` |
| `ghc-7.8.4-src.tar.xz` | `nix/ghc78` | `sha256-wxnNlK2yhBd+0ObSFUbtC5AK2EuGuHwGqZ6sNRUpgsQ=` |
| `ghc-8.0.2-src.tar.xz` | `nix/ghc80` | `sha256-EWJUU+HQaGs/pnOZiPcOysg2ytwwufDItJ75CR1hGLE=` |
| `ghc-8.4.4-src.tar.xz` | `nix/ghc84` | `sha256-ERF3NaWOUHxIHAnz85rloxTp+/SfwxCVKPmep5WQBLI=` |
| `ghc-8.8.4-src.tar.xz` | `nix/ghc88` | `sha256-8FBeOLIjX/nxCQtR9E1sjv03EGjlprtCoqbYtntf/C0=` |
| `ghc-9.0.2-src.tar.xz` | `nix/ghc90` | `sha256-FA5CuWNGMi0aOesXYCvNx24pICitSmkoayMLqxiKkZc=` |
| `ghc-9.4.8-src.tar.xz` | `nix/ghc94` | `sha256-C/QH62f+PjwksPTI3qjLY+B/Y8oPds8gWFZRQ1B6uF4=` |
| `ghc-9.8.4-src.tar.xz` | `nix/ghc98` | `sha256-F+gYjzyKXC9z+0410BAy6NwliDXsh21SyK2O49JLL8U=` |
| `happy-1.20.1.1.tar.gz`, `alex-3.2.7.4.tar.gz` (Hackage) | `nix/ghc94/happy120.nix`, `nix/ghc94/alex327.nix` | in the files |
| `src/Parser.ly`, `src/AttrGrammarParser.ly` at the `1.20.1.1` tag of github.com/haskell/happy (the Hackage tarball ships only the generated parsers) | `nix/ghc94/happy120.nix` | in the file |
| Hadrian's 18 bootstrap dependencies (Hackage tarballs and revised `.cabal` files: shake 0.19.8, QuickCheck 2.14.3, ...) | `nix/ghc98/plan-bootstrap-9_4_4.json`, copied from `ghc-9.8.4/hadrian/bootstrap/` | the plan's `src_sha256` and `cabal_sha256` fields |
| `happy-1.16.tar.gz`, `alex-2.1.0.tar.gz` (Hackage) | `nix/ghc66/happy116.nix`, `nix/ghc66/alex210.nix` | in the files |
| `gmp-6.1.2.tar.xz` (`ftp.gnu.org/gnu/gmp/`) | `nix/gmp612.nix` | `sha256-h7Vl6JqaaE/k6+7duDmdziWZ+ckEmFTKjA373qDiGRI=` |
| `hugs98-plus-Sep2006.tar.gz`, MicroHs, cpphs 1.20.9 | `nix/hugs.nix`, `nix/mhs.nix`, `nix/cpphs.nix` | in the files |

GMP 6.1.2 is the GMP every compiler before 8.0 links against: GMP 6.2's lazy
`mpz_init` breaks their Integer (DECISIONS.md D52). The host's GMP serves
8.0 and later. The release tarballs used to pick the rungs are those whose
`configure.ac` accepts the previous rung as the bootstrapping compiler.

## Extractions and outputs

Every `ghc-*` directory under `build/`, `build/ghc66-by-622/{src,src-verify}`,
`build/ghc66-by-622/ghc622-inst/src`, `phase0/hugs98-plus-Sep2006`,
`build/repro-622`, `build/rebase622/{ghc-6.0,ghc-6.2.2,try622}` and
`build/rts622/ghc-6.2.2` are extractions of the tarballs above, some with a
patch series applied; the series and the scripts that apply them are tracked,
the trees are not. Objects, interfaces, `.hc` files, archives, binaries,
`.mhscache` caches and `tmp/` directories are outputs of tracked scripts.
The tree `build/ghc-6.2.2-run1/ghc` that `phase4/reproduce-6.2.2.sh` diffs
against is recorded as `build/6.2.2-run1.patch` (whole-tree diff against the
pristine extraction, generated files excluded).
