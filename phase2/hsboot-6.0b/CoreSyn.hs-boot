module CoreSyn where
import {-# SOURCE #-} Var

-- Needed by Var.lhs
data Expr b
type CoreExpr = Expr Var.Var

