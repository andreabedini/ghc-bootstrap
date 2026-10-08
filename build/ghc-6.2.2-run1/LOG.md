# GHC 6.2.2 on mhs, run1 -- running log

One line per module: error, fix. Setup edits first.

## Setup (before the first run)

- tree: build/rebase622/try622 (6.2.2 + 6.0 patch) copied to ghc/compiler; 11 *.rej/*.orig removed.
- includes: pristine 6.2.2 ghc/includes + build/rts622 x86_64 config.h (no form feed present).
- UniqSupply.lhs: mk_supply# CAF -> `mk_supply# :: Int -> IO UniqSupply` (4.08.2 patch 0010); `foreign import ccall "genSymZh" unsafe` (safety after entity, mhs rejects) -> GhcCompat.genSym. Rebase R(b).
- TcRnDriver.lhs: HscTypes import list: dropped duplicate ModIface/ModDetails/typeEnvTyCons, named dcl_tycl/dcl_rules/dcl_insts. Rebase R(b).
- TcRnTypes.lhs: ExternalPackageState imported twice -> once as ExternalPackageState(..). Rebase R(b).
- PrelInfo.lhs: fuzz-3 misapplication put `ghcPrimExports` after the body; restored `sig; name = body`. Rebase F-wrong.
- Digraph.lhs: two new `_scc_` pragmas dropped.
- CompManager.lhs:714 `ml_hspp_file.ms_location`, DriverState.hs:554 `not.wayRTSOnly`: spaced compositions.
- SysTools.lhs:806 `foreign import ccall "rawSystem" unsafe` -> `ccall unsafe "rawSystem"` (active < 603 branch).
- shims-6.2.2-run1: copy of shims-6.0-run2 + CForeign.hs (re-export Foreign.C) + Foreign.hs (shadows ghc622/shims-ghc/Foreign.hs: PrelForeign + Foreign.Ptr/Marshal.Utils/Marshal.Array/Storable, for SysTools' private rawSystem).
- hsboot-6.2.2-run1: copy of hsboot-6.0-run2; TcMatches.hs-boot tcGRHSs -> tcGRHSsPat (no HsMatchContext arg); DataCon.hs-boot + dataConInstOrigArgTys (imports TypeRep SOURCE).
- ghc622/gen/Config.hs: 6.2.2 / 602 / "2"; other 33 fields unchanged (Makefile CONFIG_HS rule emits the same set).
- build/order-6.2.2.txt: 235 modules = build-order-6.2.2.txt minus PrelNum, Foo, Test17/18/19/1_nostdlib, life, test*, yes, yes2 (31 non-modules).
- build/probe-ordered-622.sh: same defines as probe-ordered-slit.sh (see header): __GLASGOW_HASKELL__=408, no HscIfaceFileVersion, OMIT_NATIVE_CODEGEN, no GHCI.

## Run 1 (FRESH=1)

- HscMain.lhs:155: new 6.2.2 `_scc_ "tcRnIface"` (not in the 6.0 patch) dropped, pre-emptively.
- Outputable (via Packages.lhs): undefined type PackageConfig: Packages.lhs #includes ../utils/ghc-pkg/Package.hs; copied ghc/utils/ghc-pkg from the 6.2.2 tarball to ghc/utils and symlinked ghc/compiler/utils/ghc-pkg -> ../../utils/ghc-pkg as 6.0-run2 did (Package.hs is byte-identical 6.0/6.2.2, unedited). Restarted FRESH=0. Note: never pkill -f a pattern that appears in the calling command line.
- (session restart killed the probe at row 18; relaunched FRESH=0, cache intact: .mhscache == .mhscache.good)
- gen622/READY appeared at row 28 (Var failed via missing primop-*.hs-incl); copied 10 primop-*.hs-incl + primops.txt, parser/Parser.hs, parser/ParserCore.hs, main/ParsePkgConf.hs from build/gen622; restarted FRESH=0.
- lexer622/READY at row 34: copied build/lexer622/Lexer.hs -> parser/Lexer.hs, build/lexer622/StringBuffer.hs -> shims-6.2.2-run1/StringBuffer.hs (new 11-function API), build/lexer622/overlay/SrcLoc.lhs -> basicTypes/SrcLoc.lhs (strict !FastInt line/column; FastInt is a lazy Int under the shims, one thunk per character otherwise). SrcLoc is row 15: mhs validateCache invalidates it and every dependent by md5, so restarted FRESH=0 rather than let one later invocation redo ~20 modules inside a single 1200 s window.
- DerivedConstants.h note: lexer622 generated it without -DUSE_MINIINTERPRETER and got STD_ITBL_SIZE 2 (== 6.0-run2); ours was built with includes/Makefile's unregisterised flags (-DNO_REGS -DUSE_MINIINTERPRETER => no TABLES_NEXT_TO_CODE => an entry pointer in the info table) and says 3. Kept 3: it is the value an unregisterised x86_64 build uses; it only affects code generation constants, not typechecking.
- SysTools.lhs:92: new 6.2.2 `#if __GLASGOW_HASKELL__ < 500 / #error GHC >= 5.00 is required` fires under our -D__GLASGOW_HASKELL__=408; guarded with && !defined(__MHS__) (mhs's cpphs defines __MHS__). Restarted FRESH=0 (DriverState, row 69, imports it).
- SysTools.lhs:934 `getBaseDir :: IO (Maybe String) = do return Nothing` (SIG, the 6.2.2 successor of 6.0's getExecDir hunk; mhs reported it as line 762 col 33: .lhs line numbers in mhs messages are offset, PrimPacked's 'line 210' is really 245): split. Not restarted; DriverState and the main/ chain fail this pass and go into pass 2.
- side probes: a fresh-cache probe of an early module costs ~90 s, so fixes are checked in side caches (build/probe-side*.tsv) instead of restarting the main pass. side2 = the 67 modules downstream of SysTools (build/order-side2.txt), own cache, MODTIMEOUT=3600, running in parallel with the main pass; pass 2 (FRESH=0, failed modules only, in order) validates everything in the one cache afterwards.
- TcRnMonad.lhs:765 `getBannedProcLevels :: TcM [ProcLevel]` / `  = do {...}` (SIG, new arrow code in 6.2.2; found by side2 via DsUtils): split.
- CgHeapery.lhs:12-14: export list had `allocDynClosure,` then `,fetchAndReschedule` (double comma; new in 6.2.2): removed the second comma. Found by main pass row 112 and side2 (CgCon).
- RnSource.lhs:52: PrelNames import list `, objectTyConName, ` followed by `, unmarshalObjectName` (double comma, new dotnet interop names in 6.2.2): dropped the trailing comma. Found by a tree-wide double-comma scan.
- DsMeta.hs: undefined type M.StrictTypeQ: the Language.Haskell.THSyntax shim was 6.0's; replaced by 6.2.2's libraries/haskell-src/Language/Haskell/THSyntax.hs (from build/rts622) with the same edits (Prelude hiding ((<>)), Functor/Applicative/MonadFail Q, MonadIO from Control.Monad.IO.Class); old one kept as THSyntax.hs.60. side3: DsMeta OK. (DsMeta is only imported under GHCI; not on Main's path.)
- TcArrows.lhs:171-172 (new module): `do { -- comment` then `; checkTc ...` (SEMI: mhs rejects the empty statement): leading ';' removed. Found by side2 via Inst (main row 198).
- side2 done: 63/67 OK; FAIL = DsUtils (transient: TcRnMonad fixed while it ran; MatchLit etc. compiled it on demand afterwards), DsMeta (fixed; side3 OK), Linker + InteractiveUI (GHCi cascade, expected). HscMain, DriverPipeline, CompManager, Main, TcSplice all OK in the side cache.

## Pass 1 result (build/probe-6.2.2-run1-pass1.tsv, 05:04)

223 OK / 235. Main OK at row 233; TcSplice OK. FAIL (12): PrimPacked (shadowed by the FastString shim; old-order FFI), SysTools + DriverState (compiled before the getBaseDir fix), CgHeapery (compiled before the double-comma fix), ByteCodeInstr/Asm/Link/Gen + Linker + InteractiveUI (GHCi: GHC.Ptr), IlxGen, JavaGen (dead backends, same as 6.0).

## Pass 2 (FRESH=0, build/order-6.2.2-pass2.txt, same cache; build/probe-6.2.2-run1-pass2.tsv)

SysTools, DriverState, CgHeapery, DsMeta: 4/4 OK. Merged result: build/probe-6.2.2-run1-final.tsv = 226 OK / 235; 9 FAIL, all off Main's path.
