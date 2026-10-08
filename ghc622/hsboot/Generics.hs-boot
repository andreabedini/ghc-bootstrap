module Generics where
import BasicTypes
import {-# SOURCE #-} Name
import {-# SOURCE #-} TyCon
import {-# SOURCE #-} Var

mkTyConGenInfo ::  TyCon.TyCon -> [Name.Name]
	 -> Maybe (BasicTypes.EP Var.Id)
