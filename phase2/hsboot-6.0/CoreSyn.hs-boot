module CoreSyn where
import {-# SOURCE #-} Var

type CoreExpr = Expr Var.Var
data Expr b
