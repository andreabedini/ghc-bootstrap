module TcMatches where
import {-# SOURCE #-} HsExpr
import {-# SOURCE #-} Name
import RnHsSyn
import TcHsSyn
import TcRnTypes
import {-# SOURCE #-} TcType
import {-# SOURCE #-} TcUnify

tcGRHSsPat    :: RnHsSyn.RenamedGRHSs
	      -> TcUnify.Expected TcType.TcType
	      -> TcRnTypes.TcM TcHsSyn.TcGRHSs

tcMatchesFun :: Name.Name
	     -> [RnHsSyn.RenamedMatch]
	     -> TcUnify.Expected TcType.TcType
	     -> TcRnTypes.TcM [TcHsSyn.TcMatch]

