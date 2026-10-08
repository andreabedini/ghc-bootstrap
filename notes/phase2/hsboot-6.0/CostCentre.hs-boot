module CostCentre where
import FastString

data CostCentre
noCostCentre :: CostCentre
useCurrentCostCentre :: CostCentre
overheadCostCentre :: CostCentre
dontCareCostCentre :: CostCentre
subsumedCosts :: CostCentre
preludeCafsCostCentre :: CostCentre
mkAllCafsCC :: FastString.FastString -> FastString.FastString -> CostCentre
preludeDictsCostCentre :: Bool -> CostCentre
mkAllDictsCC :: FastString.FastString -> FastString.FastString -> Bool -> CostCentre
cafifyCC :: CostCentre -> CostCentre
mkUserCC :: FastString.FastString -> FastString.FastString -> FastString.FastString -> CostCentre
