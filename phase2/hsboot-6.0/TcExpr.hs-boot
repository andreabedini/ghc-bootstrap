module TcExpr where
import RnHsSyn
import TcHsSyn
import TcMonad
import {-# SOURCE #-} TcType

tcExpr :: forall s . RnHsSyn.RenamedHsExpr -> TcType.TcType -> TcMonad.TcM s (TcHsSyn.TcExpr, TcMonad.LIE)
tcMonoExpr :: forall s . RnHsSyn.RenamedHsExpr -> TcType.TcType -> TcMonad.TcM s (TcHsSyn.TcExpr, TcMonad.LIE)
