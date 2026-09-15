module TcUnify where
import TcRnTypes
import {-# SOURCE #-} TcType

unifyTauTy :: TcType.TcTauType -> TcType.TcTauType -> TcRnTypes.TcM ()
