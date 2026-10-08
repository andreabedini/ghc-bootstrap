module Subst where
import {-# SOURCE #-} TypeRep
import {-# SOURCE #-} Var

data Subst
mkTyVarSubst :: [Var.TyVar] -> [TypeRep.Type] -> Subst
substTy :: Subst -> TypeRep.Type -> TypeRep.Type
