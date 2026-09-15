module Match where
import {-# SOURCE #-} CoreSyn
import DsMonad
import {-# SOURCE #-} DsUtils
import TcHsSyn
import {-# SOURCE #-} Var

match :: [Var.Id] -> [DsUtils.EquationInfo] -> DsMonad.DsM DsUtils.MatchResult
matchExport :: [Var.Id] -> [DsUtils.EquationInfo] -> DsMonad.DsM DsUtils.MatchResult
matchSimply :: CoreSyn.CoreExpr -> DsMonad.DsMatchKind -> TcHsSyn.TypecheckedPat -> CoreSyn.CoreExpr -> CoreSyn.CoreExpr -> DsMonad.DsM CoreSyn.CoreExpr
matchSinglePat :: CoreSyn.CoreExpr -> DsMonad.DsMatchContext -> TcHsSyn.TypecheckedPat -> DsUtils.MatchResult -> DsMonad.DsM DsUtils.MatchResult
