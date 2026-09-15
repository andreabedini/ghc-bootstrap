module Subst where
import {-# SOURCE #-} TypeRep
import Var

data Subst
substTyWith :: [Var.TyVar] -> [TypeRep.Type] -> TypeRep.Type -> TypeRep.Type
