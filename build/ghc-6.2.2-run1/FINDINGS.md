# GHC 6.2.2 compiler tree under mhs -- run1

*2026-09-09/10. Result: **Main compiles** (mhs `-C -c`, codegen mode, one shared
cache, dependency order). 226 of 235 modules OK; the 9 failures are GHCi, the
dead ILX/Java backends and one shadowed module. Stop condition (a) reached.*

Tree `build/ghc-6.2.2-run1/ghc/{compiler,includes,utils}`, log
`build/ghc-6.2.2-run1/LOG.md`, results `build/probe-6.2.2-run1-final.tsv`,
patch `build/6.2.2-run1.patch`, script `build/probe-ordered-622.sh`.

## 1. Setup decisions

- **Tree**: `build/rebase622/try622` (pristine 6.2.2 + the 6.0 edit patch) copied to
  `ghc/compiler`; 11 `*.rej`/`*.orig` removed. Plus `ghc/utils/ghc-pkg/` from the tarball
  and the symlink `ghc/compiler/utils/ghc-pkg -> ../../utils/ghc-pkg`: `main/Packages.lhs`
  `#include`s `../utils/ghc-pkg/Package.hs` (6.0-run2 had the same symlink; it was excluded
  from the 6.0 patch, which is why the rebase dry-run did not list it). Without it
  Outputable fails and nothing compiles.
- **Includes**: pristine 6.2.2 `ghc/includes` + the x86_64 `config.h` from `build/rts622`
  (no form feed; `rg -l $'\f'` empty) + `DerivedConstants.h`, generated with gcc from
  `mkDerivedConstants.c` using `includes/Makefile`'s unregisterised flags
  (`-DNO_REGS -DUSE_MINIINTERPRETER`). That gives `STD_ITBL_SIZE 3` (an entry pointer in
  the info table because there is no TABLES_NEXT_TO_CODE); 6.0-run2 and lexer622
  generated it without those flags and have 2. Kept 3: it is the value an unregisterised
  x86_64 build uses. It only feeds code-generation constants; typechecking is unaffected.
- **cpp defines**: identical to `build/probe-ordered-slit.sh`:
  `-D__HASKELL__=98 -D__HASKELL1__=5 -D__GLASGOW_HASKELL__=408 -D__HASKELL98__
  -D__CONCURRENT_HASKELL__ -DOMIT_NATIVE_CODEGEN`. `__GLASGOW_HASKELL__=408` kept:
  HsVersions.h maps GLAEXTS/DATA_BITS/UNSAFE_IO/... to the pre-hierarchical names the
  shims provide. Two 6.2.2 consequences, both handled: SysTools takes its `< 603` branch
  (private `rawSystem`, imports `CForeign` and `Foreign(withMany, withArray0, nullPtr,
  Ptr)`, hence two new shims), and a new `#if __GLASGOW_HASKELL__ < 500 / #error` in
  SysTools had to be guarded. No `-DHscIfaceFileVersion` (6.2.2 reads
  `cHscIfaceFileVersion` from Config.hs; `rg` finds no cpp reference in the sources,
  only Makefile:192). GHCI not defined, as in 6.0-run2. The script header records this.
- **Order**: `build/order-6.2.2.txt` = `build/rebase622/build-order-6.2.2.txt` minus the
  31 non-modules (PrelNum, Foo, Test17/18/19/1_nostdlib, life, test*, yes, yes2):
  235 modules. nativeGen excluded as before.
- **Config**: `ghc622/gen/Config.hs` = gen-6.0 with cProjectVersion "6.2.2",
  cProjectVersionInt "602", cProjectPatchLevel "2" (`ghc/mk/version.mk`); the
  `$(CONFIG_HS)` rule emits the same 36 fields, nothing else differs.
- **Shims** `ghc622/shims` = shims-6.0-run2 plus: `CForeign.hs` (re-export
  Foreign.C); `Foreign.hs` (PrelForeign + Foreign.Ptr/Marshal.Utils/Marshal.Array/
  Storable, shadows ghc622/shims-ghc/Foreign.hs which only had ForeignObj);
  lexer622's `StringBuffer.hs` (the 11-function 6.2.2 API); `Language/Haskell/
  THSyntax.hs` replaced by 6.2.2's `libraries/haskell-src` version with the same three
  edits as before (old kept as `THSyntax.hs.60`).
- **Boot files** `ghc622/hsboot` = hsboot-6.0-run2 with `TcMatches.hs-boot`
  (tcGRHSs -> tcGRHSsPat) and `DataCon.hs-boot` (+ dataConInstOrigArgTys, imports
  TypeRep SOURCE).
- **Generated files** taken from `build/gen622` (Parser.hs, ParserCore.hs,
  ParsePkgConf.hs, 10 primop-*.hs-incl, primops.txt) and `build/lexer622`
  (parser/Lexer.hs; overlay basicTypes/SrcLoc.lhs with strict `!FastInt` line/column,
  because FastInt is a lazy Int under the shims and advanceSrcLoc otherwise leaves one
  thunk per character). All compiled unchanged: Lexer, StringBuffer, ParsePkgConf,
  PrimOp, Parser, ParserCore OK on first contact.

## 2. Result

Pass 1 (`build/probe-6.2.2-run1-pass1.tsv`, FRESH=1 then FRESH=0 restarts, one cache):
**223 OK / 235**, Main OK at row 233, TcSplice OK. Three of its 12 failures were
modules compiled *before* their fix landed (SysTools, DriverState, CgHeapery; the fix
was in the source by the time their dependents compiled them on demand, so nothing
downstream was lost). Pass 2 (`build/probe-6.2.2-run1-pass2.tsv`, FRESH=0, same cache,
`build/order-6.2.2-pass2.txt`: SysTools DriverState CgHeapery DsMeta) 4/4 OK.

**Merged: `build/probe-6.2.2-run1-final.tsv` = 226 OK / 9 FAIL / 0 TIMEOUT of 235.**
6.0-run2's best was 214/264 (+ Main in a trunk rerun); 6.2.2 is at the same mark on
the first day, with fewer open items.

### Remaining FAILs

| module | error | class |
|---|---|---|
| PrimPacked | `foreign import ccall "ghc_strlen" unsafe` (safety after entity, old FFI) | shadowed: the FastString shim replaces it; nothing imports the tree's PrimPacked. Same in 6.0. |
| ByteCodeInstr, ByteCodeAsm, ByteCodeLink, ByteCodeGen, Linker | `Module not found: GHC.Ptr` (ByteCodeInstr.lhs:20) | GHCi bytecode interpreter; GHCI is off, Main does not import them. Same in 6.0. |
| InteractiveUI | cascade of the above | GHCi front end; GHCI off. |
| IlxGen | `not exported: modulePackage` | dead .NET backend (ILX), not built by GHC either. Same in 6.0. |
| JavaGen | `undefined value: unpackFS` | dead Java backend. Same in 6.0. |

Nothing on the path to Main fails; no module needed more than a few minutes; no
MicroHs change was needed.

Side probes (own caches, `build/probe-side{1,2,3}.tsv`): side1 SysTools OK; side2 =
the 67 modules downstream of SysTools, 63/67 (DsUtils transient, DsMeta since fixed,
Linker + InteractiveUI GHCi); side3 DsMeta OK. A fresh-cache probe of an early module
costs ~90 s, so from SysTools on fixes were verified in side caches instead of paying
the ~1 h cache re-walk of a main restart.

## 3. Every edit made in this run

Tree (`ghc/compiler`, all commented `-- ... mhs ...` / `/* mhs ... */`):

| file | edit | category |
|---|---|---|
| basicTypes/UniqSupply.lhs | `mk_supply#` CAF -> `mk_supply# :: Int -> IO UniqSupply` (4.08.2 patch 0010); `foreign import ccall "genSymZh" unsafe` -> `GhcCompat.genSym` | rebase R(b) PRIM/FFI |
| typecheck/TcRnDriver.lhs | HscTypes import list: duplicates (ModIface, ModDetails, typeEnvTyCons) dropped, dcl_tycl/dcl_rules/dcl_insts named | rebase R(b) DUP/ABS |
| typecheck/TcRnTypes.lhs | ExternalPackageState imported twice -> once as (..) | rebase R(b) DUP |
| prelude/PrelInfo.lhs | fuzz-3 misapplication of the SIG hunk repaired (`ghcPrimExports` name back before `=`) | rebase F-wrong SIG |
| utils/Digraph.lhs | two `_scc_` dropped | new SCC |
| compMan/CompManager.lhs:714, main/DriverState.hs:554 | `ml_hspp_file . ms_location`, `not . wayRTSOnly` | new DOT |
| main/HscMain.lhs:155 | `_scc_ "tcRnIface"` dropped | new SCC |
| main/SysTools.lhs:92 | `#if __GLASGOW_HASKELL__ < 500` `#error` guarded with `&& !defined(__MHS__)` | new CPP |
| main/SysTools.lhs:806 | `foreign import ccall "rawSystem" unsafe` -> `ccall unsafe "rawSystem"` | new FFI |
| main/SysTools.lhs:934 | `getBaseDir :: IO (Maybe String) = do return Nothing` split | new SIG (successor of 6.0's getExecDir hunk) |
| typecheck/TcRnMonad.lhs:765 | `getBannedProcLevels :: TcM [ProcLevel]` / `= do {...}` split | new SIG (arrows) |
| typecheck/TcArrows.lhs:172 | leading `;` after `do {` removed | new SEMI (arrows) |
| codeGen/CgHeapery.lhs:14 | `allocDynClosure,` / `,fetchAndReschedule` double comma | new TC |
| rename/RnSource.lhs:52 | `, objectTyConName, ` / `, unmarshalObjectName` double comma | new TC (dotnet names) |
| basicTypes/SrcLoc.lhs | strict `!FastInt` line/column (lexer622 overlay) | new (runtime, not typecheck) |
| parser/Lexer.hs | lexer622's converted alex output (excluded from the patch) | GEN |

Outside the compiler tree: `ghc/utils/ghc-pkg` + symlink; `ghc/includes/config.h`,
`DerivedConstants.h`; shims CForeign.hs, Foreign.hs, StringBuffer.hs, THSyntax.hs;
hsboot TcMatches, DataCon; `ghc622/gen/Config.hs`; `build/order-6.2.2.txt`,
`build/order-6.2.2-pass2.txt`, `build/order-side{1,2,3}.txt`; `build/probe-ordered-622.sh`.

Tree-wide scans run to pre-empt the classes hit (all negative after the fixes above):
`#include` targets missing from the tree (only the primop includes); `#error`
directives (SMRep, Binary already OK); fused `name :: T` / `= e` pairs; `{ ... ;` empty
statements; double commas in export/import lists; Monad instances without
Functor/Applicative.

### Patch

`build/6.2.2-run1.patch` = `diff -ruN build/rebase622/ghc-6.2.2/ghc/compiler
build/ghc-6.2.2-run1/ghc/compiler` excluding primop-*.hs-incl, primops.txt, Parser.hs,
ParserCore.hs, ParsePkgConf.hs, Lexer.hs, tmp, ghc-pkg (symlink):
**101 files, 187 hunks, 132 KB.** Versus the 6.0 patch (103 files / 244 hunks incl. 27
regeneration hunks): new files SrcLoc, CgHeapery, DriverState, TcArrows, TcRnMonad,
Digraph; gone CorePrep, CmdLineOpts, Finder, Lex (upstream fixes / file removed) and
the three regenerated parsers (now excluded).

## 4. Observations worth keeping

- mhs's line numbers for `.lhs` files are offset (PrimPacked "line 210" is line 245,
  SysTools "762" is 934). Locate by column with `expand | awk 'substr($0,C,1)=="="'`.
- mhs's `-C` cache invalidates by md5 of the module source and transitively (Compile.hs
  `validateCache`), so a fixed early module forces a recompile of everything above it
  inside one later invocation; restart in order instead. A failed module is never
  cached, so a fix landed before a dependent is reached heals the dependent for free.
- With FRESH=0 a cached row still costs 30-60 s (codegen of the closure), so a
  restart at row N costs about N minutes; side caches are the cheap way to test a fix.
- Never `pkill -f <pattern>` from a shell whose own command line contains the pattern;
  background jobs must use the harness's run_in_background, a `( ... & )` subshell dies
  with the call.

## 5. What next

1. Fold the patch into `phase2/patches` style (one concern per patch) together with
   gen622's and lexer622's recipes; add `probe-ordered-622.sh`, the order files and
   `gen-6.2.2` to the reproduction steps.
2. Link: the mhs codegen output exists for Main (`out.comb` per invocation); build a
   real `ghc` binary with mhs (as `build/compile-ghc.sh` did for 4.08.2's hsc) and run
   it on a Prelude module to find the runtime-behaviour gaps (unsafeInterleaveIO
   semantics, FastString/StringBuffer shims, the lazy-Int `FastInt`).
3. Then the 6.2.2 libraries (`libraries/base` with 6.2.2's own `.hc` route) against
   the RTS from `build/rts622`, which is the point of moving to 6.2.2: x86-64 is a
   known platform there.
4. Optional: GHCi modules need a `GHC.Ptr`/`GHC.Exts` shim set (7 modules); IlxGen and
   JavaGen are not worth it.
