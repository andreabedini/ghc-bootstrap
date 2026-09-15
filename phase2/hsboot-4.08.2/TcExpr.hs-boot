module TcExpr where
import Inst
import RnHsSyn
import TcHsSyn
import TcMonad

tcExpr :: forall s . RnHsSyn.RenamedHsExpr -> TcMonad.TcType -> TcMonad.TcM s (TcHsSyn.TcExpr, Inst.LIE)
