module DsExpr where
import {-# SOURCE #-} CoreSyn
import DsMonad
import TcHsSyn

dsExpr :: TcHsSyn.TypecheckedHsExpr -> DsMonad.DsM CoreSyn.CoreExpr
dsLet :: TcHsSyn.TypecheckedHsBinds -> CoreSyn.CoreExpr -> DsMonad.DsM CoreSyn.CoreExpr
