module TcUnify where
import TcRnTypes
import {-# SOURCE #-} TcType

-- This boot file exists only to tie the knot between
--		TcUnify and TcSimplify

unifyTauTy :: TcType.TcTauType -> TcType.TcTauType -> TcRnTypes.TcM ()


