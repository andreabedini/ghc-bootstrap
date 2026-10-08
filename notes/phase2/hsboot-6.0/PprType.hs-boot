module PprType where
import Outputable
import {-# SOURCE #-} Type
import {-# SOURCE #-} TypeRep

pprType :: TypeRep.Type -> Outputable.SDoc
pprPred :: Type.PredType -> Outputable.SDoc
