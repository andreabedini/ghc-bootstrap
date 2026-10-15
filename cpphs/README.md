# cpphs

cpphs 1.20.9, the C preprocessor [mhs](../mhs/README.md) runs on every module
that uses CPP. It is built from source by mhs, and the awkward part is that
cpphs's own sources need a cpp before there is a cpphs.

```sh
nix-build -A cpphs
```

## How it is built

- **Round 1:** gcc's traditional cpp, which is what GHC's own `-cpp` runs,
  preprocesses the polyparse modules (the only ones with directives). cpphs
  is then compiled with no CPP at all.
- **Round 2:** upstream's `make bootstrapcpphs` command, run with round 1's
  cpphs. This is the cpphs that gets installed.
- **Round 3:** the same command with round 2's cpphs. The check phase requires
  its C to equal round 2's.

The result replaces MicroHs's shipped `generated/cpphs.c`, and as far as the
chain can tell it behaves the same. Both preprocess every `.hs`, `.lhs` and
`.pp` file of GHC 6.2.2 with the chain's three flag sets to identical output
(1,458 runs, 2026-09-30). The one difference is the source path in cpphs's own
`#error` message.

## Files

| File | What it is |
|---|---|
| `default.nix` | the derivation: the cpphs and polyparse releases from Hackage, and the three rounds |
| `cpphs-1.20.9-mhs.patch` | the edits MicroHs's cpphs submodule (malcolm-wallace-universe 3ec065411afb) makes to cpphs: `defaultTimeLocale` from MicroHs's `TimeCompat`, spaces around composition dots |
| `polyparse-1.12-mhs.patch` | the same submodule's edits to polyparse, the parser library cpphs needs: `MonadFail` instances |

cpphs is LGPL 2.1 (library) and GPL 2 (program), and polyparse is LGPL 2.1.
The patches stay under those licences.
