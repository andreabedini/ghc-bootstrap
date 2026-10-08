module HsMatches where
import Outputable

data Match a b
data GRHSs a b
pprGRHSs :: forall i p . (Outputable.Outputable i, Outputable.Outputable p) => Bool -> GRHSs i p -> Outputable.SDoc
pprMatch :: forall i p . (Outputable.Outputable i, Outputable.Outputable p) => (Bool, Outputable.SDoc) -> Match i p -> Outputable.SDoc
pprMatches :: forall i p . (Outputable.Outputable i, Outputable.Outputable p) => (Bool, Outputable.SDoc) -> [Match i p] -> Outputable.SDoc
