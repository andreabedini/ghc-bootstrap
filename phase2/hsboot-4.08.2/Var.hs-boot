module Var where
import {-# SOURCE #-} Name

type Id = Var
type TyVar = Var
type UVar = Var
data Var
setIdName :: Id -> Name.Name -> Id
