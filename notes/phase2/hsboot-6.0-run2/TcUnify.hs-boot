module TcUnify where
import TcRnTypes
import {-# SOURCE #-} TcType

-- This boot file exists only to tie the knot between
--		TcUnify and TcSimplify

unifyTauTy :: TcType.TcTauType -> TcType.TcTauType -> TcRnTypes.TcM ()



-- TcExpr.hs-boot names TcUnify.Expected, which the interface boot never
-- declared (GHC resolved it against the real interface).
data Expected ty
