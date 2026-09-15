module MkId where
import {-# SOURCE #-} DataCon
import {-# SOURCE #-} Name
import {-# SOURCE #-} Var

mkDataConId :: Name.Name -> DataCon.DataCon -> Var.Id
mkDataConWrapId :: DataCon.DataCon -> Var.Id
