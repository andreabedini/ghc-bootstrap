# GHC 9.0.2

Built by the chain's [GHC 8.8.4](../ghc88/README.md) with `configure && make`:
registerised with the native code generator, GHCi, SMP, static only. It builds
[GHC 9.4.8](../ghc94/README.md). 9.0.2 asks for 8.8 or later; 8.10 is skipped.

```sh
nix-build -A ghc90
```

## Files

| File | What it is |
|---|---|
| `default.nix` | the derivation |
| `StgCRunAsm-only-when-needed.patch` | upstream commit d61f7428 (#21478, Ben Gamari), as Guix carries it for 9.0 to 9.4 |

## Notes

- **The StgCRunAsm patch.** The make build system linked `rts/StgCRunAsm.S`
  into the RTS on every architecture. On x86-64 that object is empty and has
  no `.note.GNU-stack`. With a binutils before 2.44, every program linked
  against the RTS was therefore marked as needing an executable stack.
  Hadrian never had the problem, and make never got the fix.
- **The tarball ships build products.** It carries a dirty containers
  checkout: `dist-install/` holds the `.o`, `.a`, `.so` and `.hi` files of the
  release manager's build, and there is a stray `utils/hsc2hs/test.o`. Nothing
  links them; the derivation deletes them before anything runs.
- **`--with-gmp-includes` and `--with-gmp-libraries`**, as nixpkgs passes them.
  From 9.0 on, ghc-bignum records a GMP library directory only when it is told
  one. Without it, 9.4.8 could not link a program outside Nix.
- **Parsers and lexers** are regenerated with 8.8.4's happy 1.19.12 and 7.4.2's
  alex 3.2.7.4. happy 1.19.12 made the shipped parsers, so the comparison is
  strict.
- **Non-PIE** through the cc wrapper. **Test:** `common/test/T3.hs`.
