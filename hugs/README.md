# Hugs 98

The root of the chain: Hugs 98 (September 2006), compiled from source by the
host's gcc. As far as I know it is the only Haskell implementation written in
C that still builds. Here it runs the MicroHs compiler, the
[next link](../mhs/README.md).

```sh
nix-build -A hugs
```

## Files

| File | What it is |
|---|---|
| `default.nix` | the derivation: `hugs98-plus-Sep2006.tar.gz` (see [`SOURCES.md`](../SOURCES.md)), the two patches, configure and make |
| `build-hugs.sh` | the same build without Nix, into `build/hugs`; its header explains the three fixes a 2026 gcc needs |
| `patches/0002-hugs-pattern-guards.patch` | pattern guards, which Hugs never implemented and MicroHs's source uses in at least 64 places |
| `patches/0003-hugs-bigger-control-stack.patch` | a bigger control stack (`NUM_STACK`), so Hugs can interpret the MicroHs compiler |

## Notes

- **The permissive C flags go in `CC`, not `CFLAGS`.** gcc 14 and later reject
  the K&R C of the 2006 configure probes, and one probe runs `${CC} -shared`
  without `$CFLAGS`. Get this wrong and configure silently decides Hugs can't
  build shared objects; you find out much later, when every FFI stub fails to
  link. The flags are also exported for `make`, because `make_bootlib`
  configures `packages/base` in a subshell.
- **I fix the seed compiler rather than the program it compiles.** Patching
  Hugs once works for every program it will ever compile, and it doesn't need
  redoing every time MicroHs grows a new pattern guard ([D18](../DECISIONS.md#d18--hugs-is-patched-for-pattern-guards-not-microhss-source)). Upstream's
  Hugs (augustss/hugs98-plus-Sep2006) carries the same change.
- **The qualifiers are matched once**, in a binding lifted into the enclosing
  `where`, not duplicated into the guard and the body. A guarded right-hand
  side's test and body are separate expressions, so a type that only the body
  fixes (`Just line <- … >>= readMaybe`) would be ambiguous in a duplicated
  test, and Hugs would reject well-typed Haskell 2010.
