module HsExpr where
import HsPat
import Outputable

data HsExpr i p
pprExpr :: forall i . (Outputable.OutputableBndr i) => HsExpr i -> Outputable.SDoc
data Match a b
data GRHSs a b
pprPatBind :: forall i . (Outputable.OutputableBndr i) => HsPat.Pat i -> GRHSs i -> Outputable.SDoc
pprFunBind :: forall i p . (Outputable.OutputableBndr i) => i -> [Match i] -> Outputable.SDoc
