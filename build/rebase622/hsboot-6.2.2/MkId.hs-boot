module MkId where
import {-# SOURCE #-} DataCon
import {-# SOURCE #-} Name
import Var

mkDataConWorkId :: Name.Name -> DataCon.DataCon -> Var.Id
