module TcType where
import {-# SOURCE #-} TypeRep

data TyVarDetails
-- synonyms the other boot files reference as Type.TcType (an interface-file
-- spelling); they are defined here in the real module
type TcType = TypeRep.Type
type TcTauType = TcType
