module DataCon where
import {-# SOURCE #-} TypeRep

data DataCon
isExistentialDataCon :: DataCon -> Bool
dataConInstOrigArgTys :: DataCon -> [TypeRep.Type] -> [TypeRep.Type]
