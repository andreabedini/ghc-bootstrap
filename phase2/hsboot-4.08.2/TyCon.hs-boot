module TyCon where
import {-# SOURCE #-} Name

data TyCon
isTupleTyCon :: TyCon -> Bool
isUnboxedTupleTyCon :: TyCon -> Bool
isFunTyCon :: TyCon -> Bool
setTyConName :: TyCon -> Name.Name -> TyCon
