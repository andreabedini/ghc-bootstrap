module Subst where
import {-# SOURCE #-} TypeRep
import {-# SOURCE #-} Var

data Subst
substTyWith :: [Var.TyVar] -> [TypeRep.Type] -> TypeRep.Type -> TypeRep.Type
