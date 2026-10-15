# GHC 9.8.4

Built by the chain's [GHC 9.4.8](../ghc94/README.md), and the first GHC in the
chain built with Hadrian. It builds [GHC 9.12.4](../ghc912/README.md). 9.8.4
asks for 9.4 or later; 9.6 is skipped.

```sh
nix-build -A ghc98
```

The Hadrian build is shared with 9.12.4 and 9.14.1. `common/hadrian-ghc.nix`
explains it:
- `hadrian/bootstrap/bootstrap.py` builds Hadrian with a bare GHC from a
  bootstrap plan;
- the plan's Hackage tarballs are fetched by Nix with the plan's hashes;
- the flavour is the default, linked statically, with no profiling and no docs.

## Files

| File | What it is |
|---|---|
| `default.nix` | the derivation, through `common/hadrian-ghc.nix` |
| `plan-bootstrap-9_4_4.json` | 9.8.4's newest bootstrap plan, for a 9.4.4 boot compiler, copied verbatim from the tarball's `hadrian/bootstrap/`. The derivation rewrites its boot-library versions to the chain's 9.4.8's |
| `hp2ps-C-gnu17.patch` | upstream's fix for #25662 (in 9.10 and later), by Jens Petersen |

## Notes

- **hp2ps and C23.** gcc 15 defaults to C23, where `extern void *realloc();`
  declares a function of no arguments. So `utils/hp2ps/Utilities.c` fails to
  compile. The patch includes `stdlib.h` instead; nixpkgs applies the same
  patch to GHC before 9.10.
