module DataCon where
import {-# SOURCE #-} TypeRep

data DataCon
dataConRepType :: DataCon -> TypeRep.Type
isExistentialDataCon :: DataCon -> Bool
