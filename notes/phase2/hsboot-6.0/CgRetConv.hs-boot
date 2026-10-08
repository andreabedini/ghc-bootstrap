module CgRetConv where
import {-# SOURCE #-} TyCon

data CtrlReturnConvention = VectoredReturn Int | UnvectoredReturn Int
ctrlReturnConvAlg :: TyCon.TyCon -> CtrlReturnConvention
