module CoreSyn where
import Var

type CoreExpr = Expr Var.Var
data Expr b
