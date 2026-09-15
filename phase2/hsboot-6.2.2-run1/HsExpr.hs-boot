module HsExpr where
import {-# SOURCE #-} HsPat
import Outputable

data HsExpr i
data Match a
data GRHSs a

pprExpr :: (Outputable.OutputableBndr i) => 
	HsExpr.HsExpr i -> Outputable.SDoc

pprPatBind :: (Outputable.OutputableBndr i) => 
	HsPat.Pat i -> HsExpr.GRHSs i -> Outputable.SDoc

pprFunBind :: (Outputable.OutputableBndr i) => 
	i -> [HsExpr.Match i] -> Outputable.SDoc
-- TcMatches.hs-boot names HsExpr.HsMatchContext (never declared in the interface boot).
data HsMatchContext id
