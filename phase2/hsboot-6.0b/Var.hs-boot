module Var where
import {-# SOURCE #-} Name

-- Used by Name
type Id = Var
type TyVar = Var
data Var
setIdName :: Id -> Name.Name -> Id
