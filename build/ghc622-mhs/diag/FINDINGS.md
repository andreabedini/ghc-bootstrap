# DECISION (2026-09-10 10:05): full rebuild of base with the fixed binary

The collision is not confined to the three modules that looped. Concretely
(section 7): `Foreign/C/Types.hc` has the *worker* `GHCziFloat_zdwzdszddmatan2_closure`
in the `atan2` slot of its `RealFloat CFloat` dictionary (the wrapper
`$s$dmatan2` belongs there), and `GHC.Real.hi` names its five `Ratio` dfuns
only as `$s$fEnumRatio` .. `$s$fRealRatio`, whose C symbols in `GHC/Real.hc`
are the specialised CAF dictionaries; 16 downstream interfaces and four
downstream `.hc` files reference them. So downstream objects *are* wrong, not
merely unverifiable. Per the coordinator's instruction: the existing
`libraries/base` `.hi/.hc` and `hcobj/*.o` are left untouched (a link agent
is archiving them); the rebuilt set is produced beside them:

- sources: `libraries/base-rebuild/` (rsync of `libraries/base` without
  `.hi/.hc/.o/*_stub.*`), topdir `diag/topdir-rebuild/` (symlinks to the
  original, `libraries/base` -> `base-rebuild`)
- `diag/run-base-rebuild.sh` (run-base.sh with BASE/TOPDIR/OUT/LOGS as
  parameters), results `diag/base-rebuild-results.tsv`, logs
  `diag/base-rebuild-logs/`
- `diag/build-hc-rebuild.sh` -> `diag/hcobj-rebuild/`
- check afterwards: `sh diag/scan-hi.sh libraries/base-rebuild diag/ifaces-rebuild`

Patch for the shim: `diag/faststring-intern.patch` (applies to both
`ghc622/shims/FastString.hs` and `ghc622/shims-ghc/FastString.hs`).

**Outcome (10:50):** rebuild done, 10:06-10:34 for the 143-module order plus
a 3-minute resume pass for the seven modules outside it: **147 OK / 0 FAIL**
(`diag/base-rebuild-results.tsv`, `diag/base-rebuild-extra.tsv`);
`diag/hcobj-rebuild/`: **147/147 `.o`**; `diag/scan-hi-rebuild.txt`: **no
duplicated name in any of the 147 interfaces**. The old
`libraries/base/*.hi|.hc`, `hcobj/*.o` and `base-results.tsv` are untouched.

# The three space blow-ups: a FastString unique collision in the shim

*2026-09-10, `build/ghc622-mhs/diag`. Result: **the "space blow-ups" in
`Data.Complex`, `Data.Graph` and `System.Console.GetOpt` are one bug, in
`ghc622/shims/FastString.hs`, not in the compiler and not in the
modules.** The shim's `intern` could hand two different strings the same
unique; five of the 137 finished interfaces carry such a collision, and any
`-O` importer that inlines one of the collided names loops in the simplifier
until the heap is gone. Fixed in the shim (both copies), the binary relinked,
and the whole of base rebuilt beside the old tree: **147/147 modules, 147/147
objects, zero collisions** (sections 6 and 7).*

## 1. What the three modules actually do

Not a space leak in a silent pass. `-dshow-passes -v2` (`diag/logs/{cx,gr,go}-O.log`)
shows all three finishing the gentle simplifier, Specialise, float-out and
float-in, and then entering the second `*** Simplify:` (SimplPhase 2, the
first phase with real inlining and rules) and never printing a single
`Result size` -- iteration 1 never finishes. `Data.Complex` compiles at `-O0`
in 11 s (`diag/logs/cx-O0.log`).

`-ddump-inlinings` (`diag/logs/go-inl.log`, `cx-inl-old.log`, `gr-inl-old.log`)
shows why: the log grows at ~5000 lines/s with the same cycle for ever.

| module | cycle (last 20 000 lines of the log) | collided name |
|---|---|---|
| `System.Console.GetOpt` | `$w$smaximum -> build -> foldr -> mapFB -> length -> $w$smaximum` (392 each) | `GHC.List.$w$smaximum` |
| `Data.Graph` | `$w$sminimum -> build -> foldr -> index2 -> ...` (208 each) | `GHC.List.$w$sminimum` |
| `Data.Complex` | `$w$s$dmatan2` alone (800) | `GHC.Float.$w$s$dmatan2` |

The tell-tale is the unfolding the simplifier considers for the *worker*:

```
Considering inlining
    GHCziList.zdwzdsmaximum   active: True ... guidance IF_ARGS 1 [0] 3 2  ANSWER = YES
    Unfolding = __inline_me (\ w -> case GHCziList.zdwzdsmaximum w of ww -> GHCziBase.Izh ww)
```

That is the *wrapper's* unfolding (`$smaximum = \w -> case $w$smaximum w of ww -> I# ww`)
attached to the *worker's* name. Inlining it reproduces the call it replaces,
so the simplifier never reaches a fixed point -- and it allocates as it goes,
which is the "heap exhausted" after 400-800 s.

## 2. The interfaces are wrong, not the reader

`ghc --show-iface libraries/base/GHC/List.hi` (`diag/List.iface`, lines 260-263):

```
1 $w$smaximum :: [GHC.Base.Int] -> GHC.Prim.Int# {-## __A 1 __S S __U (\ w :: [GHC.Base.Int] -> case w of ... $wlgo ww a1 ...) ##-};
1 $w$smaximum :: [GHC.Base.Int] -> GHC.Base.Int  {-## __A 1 __S Sm __P $w$smaximum 1 ##-};
...
"SPEC GHC.List.maximum" __forall {$dOrd :: {GHC.Base.Ord GHC.Base.Int}} maximum @ GHC.Base.Int $dOrd = $w$smaximum ;
```

Two signatures with the same name; the second is the wrapper `$smaximum`
(type `[Int] -> Int`, worker pointer `__P`), printed under the worker's name,
and the SPEC rule points at it. The name `$smaximum` does not occur in the
file at all. So GHC.List's `.hi` was *written* with two distinct
FastStrings sharing one unique: `Binary`'s interface dictionary is a
`UniqFM` keyed by `getUnique f` (`utils/Binary.hs`, `instance Binary
FastString`), so both names land in one dictionary slot and the string that
survives is whichever was inserted first.

`diag/scan-hi.sh` runs `--show-iface` on all 137 finished interfaces and
lists top-level signature names that occur twice (`diag/scan-hi.txt`):

| interface | collided names |
|---|---|
| `GHC.List` | `$w$smaximum` `$w$sminimum` |
| `GHC.Float` | `$w$s$dmatan2` `$w$sround` |
| `GHC.Real` | `$s$fEnumRatio` `$s$fEqRatio` `$s$fFractionalRatio` `$s$fNumRatio` `$s$fRealRatio` |
| `Data.Array.Diff` | `$w$s$fHasBoundsIOToDiffArray` |
| `Text.Html` | `$fHTMLTABLEHtml` `$s$fADDATTRS(->)` `$w$sbeside` |

Every one of them is a *derived* OccName (`OccName.mk_deriv`: `"$w" ++ str`,
`"$s" ++ str`, `"$f" ++ str`) whose parent is itself a freshly derived name
(`$smaximum` from `mkSpecOcc`, `$fEnumRatio` from the instance dfun, ...).

## 3. Root cause: re-entrant `intern` in the FastString shim

`ghc622/shims/FastString.hs` (and the identical
`ghc622/shims-ghc/FastString.hs`) replaces GHC's hash-consed ByteArray
FastString with an interned `String`:

```haskell
data FastString = FastString !Int String     -- unique, contents
mkFastString s = FastString (intern s) s

intern s = unsafePerformIO $ do
  (next, tbl) <- readIORef internTable       -- (1) snapshot
  case M.lookup s tbl of                      -- (2) forces s
    Just u  -> return u
    Nothing -> do
      writeIORef internTable (next + 1, M.insert s next tbl)   -- (3) stale tbl, stale next
      return next
```

`mkWorkerOcc occ` builds `mkFastString ("$w" ++ occNameString occ)`. The
string is lazy: its tail is `unpackFS` of the parent's FastString, and that
FastString is a thunk whose strict `!Int` field is `intern "$smaximum"`, not
yet run (nothing had demanded the specialised binder's name yet). So when (2)
compares the new string against an existing key that shares the `$w` prefix
(`$wlgo` in GHC.List), it forces the tail, which forces the parent
FastString, which runs a *nested* `intern` -- reads the same `(N, tbl)`,
writes `(N+1, tbl + {"$smaximum" -> N})`, returns N -- and then the outer call
resumes at (3) with its stale snapshot: `M.lookup` finds nothing, it writes
`(N+1, tbl + {"$w$smaximum" -> N})`, and returns N.

Net effect: `$smaximum` and `$w$smaximum` both have unique N, and
`$smaximum` is no longer in the table (a later `mkFastString "$smaximum"`
gets a *different* unique, N+1, so even the survivor is no longer equal to
itself). GHC's own `mkFastString` hashes the whole string before it touches
the table, so it never had this re-entrancy; under GHC's compiled code the
shim would have failed the same way -- this is a shim bug, not an mhs
evaluation-order difference.

Why only five interfaces, and why only at `-O`: the collision needs a
derived-of-derived name whose parent FastString was never forced before the
child was interned, *and* an existing key sharing the prefix far enough for
`compare` to reach the lazy tail. Specialise + worker/wrapper (`$w$s...`) and
specialised instance dictionaries (`$s$f...`) are the producers, both `-O`
only; a `$w` of a user-written name is safe because the parent's FastString
was forced long before, by the renamer.

## 4. Minimal reproducer (no GHC involved)

`diag/repro/Intern.hs`, built with mhs against the shim
(`build/shims-6.0-run2/FastString.hs` is the pre-fix copy):

```haskell
let c = mkFastString "$wlgo"                  -- a key sharing the "$w" prefix
let a = mkFastString "$smaximum"
    b = mkFastString ("$w" ++ unpackFS a)     -- what OccName.mkWorkerOcc does
print (uniqueOfFS b, unpackFS b); print (uniqueOfFS a, unpackFS a)
print (uniqueOfFS (mkFastString "$smaximum"))
```

| | `$wlgo` | `$w$smaximum` | `$smaximum` | `$smaximum` again |
|---|---|---|---|---|
| buggy shim (`intern-buggy`) | 1 | **2** | **2** | **3** -- COLLISION |
| fixed shim (`intern-fixed`) | 1 | 3 | 2 | 2 -- ok |

Two earlier attempts did *not* collide and explain the narrowness of the
window: with an empty table `M.lookup` never compares, and with a key
`"anything"` the comparison stops at the first character, before the lazy
tail from `a` is reached.

## 5. The fix

`intern` now forces the string to normal form *before* it reads the table,
and forces the new map before storing it (both copies of the shim, comment
`-- mhs`):

```haskell
intern s = unsafePerformIO $ do
  forceString s                    -- may run intern re-entrantly; do it first
  (next, tbl) <- readIORef internTable
  case M.lookup s tbl of
    Just u  -> return u
    Nothing -> do
      let tbl' = M.insert s next tbl
      tbl' `seq` writeIORef internTable (next + 1, tbl')
      return next

forceString s = foldr seq () s `seq` return ()
```

Files: `ghc622/shims/FastString.hs` (the one the 6.2.2 binary is
linked from), `ghc622/shims-ghc/FastString.hs` (the 4.08.2 chain's copy: same
code, same latent bug; the 4.08.2 `hsc` built from it was not relinked here).
No compiler-tree edit, so `build/6.2.2-run1.patch` is unchanged.

Relink: `build.sh comb && build.sh c && build.sh cc`. Because every module
imports FastString, mhs's MD5-validated `-C` cache invalidates almost the
whole compiler, so the `mhs` step is a cold one (9 min after all -- the mhs step ran 09:55-10:04) rather than 9 min.
The pre-fix binary is kept as `diag/ghc.pre-fs-fix` (and `ghc.comb.pre-fs-fix`).

## 6. Results

Relinked binary, `diag/verify.sh`: GHC.List's interface now has
`$smaximum` and `$w$smaximum` as two names, the `SPEC GHC.List.maximum` rule
points at `$smaximum`, and the duplicate scan is empty.

Full rebuild with the fixed binary into `libraries/base-rebuild`
(`diag/run-base-rebuild.sh`, run-base.sh's flags and `-fno-strictness`
retry, 900 s limit, `ulimit -v 6000000`):

| | old tree (run 4) | rebuilt tree |
|---|---|---|
| modules compiled | 137 / 143 | **143 / 143**, then **147 / 147** with the four `hsc2hs` products and their three importers appended (`diag/base-rebuild-order.txt`) |
| `Data.Complex` | heap exhausted after 405-812 s | **OK, 47 s** (`-O -fno-strictness`: it also hits gap 6, the demand analyser) |
| `Data.Graph` | killed at 900 s | **OK, 25 s** at plain `-O` |
| `System.Console.GetOpt` | killed at 900 s | **OK, 6 s** at plain `-O` |
| `-fno-strictness` rows | 7 | 9 (the same 7, plus `GHC.Arr` which run 4 had cached, and `Data.Complex`) |
| wall time | | 28 min for the 143 (sum of per-module times 1674 s) + 3 min for the 7 |
| `.hc -> .o` (`diag/build-hc-rebuild.sh`) | 137 / 137 | **147 / 147**, 1 min |
| duplicated names in interfaces (`diag/scan-hi.sh`) | 5 modules, 13 names | **0** |

Determinism check: of the 144 `.hc` files present in both trees, 63 are
byte-identical and 81 differ only in the names of local closures (`rVl` vs
`rU2` in `Data/Maybe.hc`): forcing strings earlier changes when the lazily
split unique supply is demanded, nothing else.

The seven modules outside `base-order.txt` were produced by another agent
meanwhile (`System.CPUTime`, `System.Time`, `System.Posix.Signals`,
`Text.Regex.Posix` from `.hsc`, and their importers `System.Directory`,
`System.Random`, `Text.Regex`); the rebuild picked their `.hs` up from the
tree and all seven compile. `Control.Parallel.Strategies` also has a source
in the tree but is in neither order file and was not built.

Not redone: the 4.08.2 `hsc` linked from `ghc622/shims-ghc/FastString.hs` has
the same latent bug; the shim copy is fixed, the binary is not relinked.
`build/6.2.2-run1.patch` is unchanged (no compiler-tree edit).

## 7. Blast radius in the 137 finished modules -- measured, not assumed

The five interfaces are wrong, and their importers were assessed on the
artefacts (`rg` over `libraries/base/**/*.hc` and over the `--show-iface`
dumps in `diag/ifaces/`):

**(a) Worker in place of wrapper -- concrete miscompilation.**
`Foreign/C/Types.hc` builds its `RealFloat CFloat` dictionary with
`(P_)&GHCziFloat_zdwzdszddmatan2_closure` in the last (`atan2`) slot -- the
*worker* `$w$s$dmatan2`, because the wrapper's name `$s$dmatan2` no longer
existed in `GHC.Float.hi`. The rebuilt file has
`(P_)&GHCziFloat_zdszddmatan2_closure`. `GHC/Float.hc` itself defines both
symbols identically in both trees (5 closure/3 entry for the wrapper, 7/13
for the worker): the module was compiled right, only its interface lied.
`Text/PrettyPrint/HughesPJ.hc`'s `GHCziFloat_zdwzdsround3` is a different,
uncollided binder (the tidier's `3` suffix) and was not affected.

**(b) Dictionary functions renamed -- reaches `-O0` importers too.** In
`GHC.Real.hi` the dfuns `$fEnumRatio`, `$fEqRatio`, `$fFractionalRatio`,
`$fNumRatio`, `$fRealRatio` exist only under the names of their `Integer`
specialisations `$s$f...Ratio` (two signatures each: the `forall a. Integral
a => ...` dfun and the `... (Ratio Integer)` CAF). The C symbol behind the
surviving name in `GHC/Real.hc` is the specialised CAF. 16 downstream
interfaces mention these names (Prelude, Numeric, GHC.Read, GHC.Int,
GHC.Word, Text.Read, Text.Read.Lex, Text.PrettyPrint(.HughesPJ),
Data.Ratio, Data.Typeable, Data.Generics.Basics/Reify, Data.Array.IO,
Data.PackedString, Foreign.C.Types) and four `.hc` files reference the
symbols: `Data/Ratio.hc` enters `GHCziReal_zdszdfNumRatio_closure` as a CAF,
`Text/Read/Lex.hc` and `GHC/Float.hc` push `zdszdfFractionalRatio` /
`zdszdfRealRatio` as arguments (16 references in `GHC/Float.hc`). Whether a
given use is the CAF or the dfun applied to a dictionary depends on which of
the two signatures the reader kept; in the rebuilt tree only
`Text/Read/Lex.hc` references a specialised CAF (4 times, legitimately, via
the SPEC rule) and no importer references the dfuns by symbol at all.

**(c) The three loopers**: `$w$smaximum` / `$w$sminimum` / `$w$s$dmatan2`
also appear in `Data.List.hi` and `Prelude.hi` (re-exports) and
`Numeric.hi`, `Foreign.C.Types.hi`, `Data.Ratio.hi` (unfoldings).
`Data.Array.Diff`'s and `Text.Html`'s collided names are referenced by no
other module.

So downstream objects *were* wrong (a), and (b) could not be ruled out
cheaply for anything using `Rational`; with `GHC.List` at position 4 and
`GHC.Real` at 13 of 143, a full rebuild was the only clean state. Done
(section 6), beside the old tree as the coordinator asked: old objects in
`hcobj/` (being archived), rebuilt ones in `diag/hcobj-rebuild/`.

## 8. Method notes

- `-dshow-passes` output is *not* buffered under the MicroHs runtime; the
  earlier "prints nothing before it dies" was because run-base.sh uses `-v1`.
- The decisive tool was `-ddump-inlinings`: a repeating cycle in the last
  20 000 lines of the log, and the unfolding printed next to the name.
- `--show-iface` plus a duplicate-name scan (`diag/scan-hi.sh`) turns a
  runtime symptom into a static check on the artefacts; worth re-running
  after any future base rerun.
- `rg` with no path argument reads stdin in this environment and hangs;
  always pass `.`.
- The intern-table pattern (`readIORef`, then a lookup that forces user
  data, then `writeIORef`) is the thing to look for in any other shim that
  hands out identities from `unsafePerformIO`; a grep found no second
  instance in `ghc622/shims`, `common/shims*`.
