module TcMatches where
import {-# SOURCE #-} HsExpr
import Inst
import {-# SOURCE #-} Name
import RnHsSyn
import TcHsSyn
import TcMonad
import {-# SOURCE #-} Var

tcGRHSs :: forall s . RnHsSyn.RenamedGRHSs -> TcMonad.TcType -> HsExpr.StmtCtxt -> TcMonad.TcM s (TcHsSyn.TcGRHSs, Inst.LIE)
tcMatchesFun :: forall s . [(Name.Name,Var.Id)] -> Name.Name -> TcMonad.TcType -> [RnHsSyn.RenamedMatch] -> TcMonad.TcM s ([TcHsSyn.TcMatch], Inst.LIE)
