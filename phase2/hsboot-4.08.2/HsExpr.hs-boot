module HsExpr where
import Outputable

data HsExpr i p
pprExpr :: forall i p . (Outputable.Outputable i, Outputable.Outputable p) => HsExpr i p -> Outputable.SDoc
