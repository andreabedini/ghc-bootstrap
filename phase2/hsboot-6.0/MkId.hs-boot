module MkId where
import {-# SOURCE #-} DataCon
import {-# SOURCE #-} Name
import {-# SOURCE #-} Var

mkDataConWorkId :: Name.Name -> DataCon.DataCon -> Var.Id
