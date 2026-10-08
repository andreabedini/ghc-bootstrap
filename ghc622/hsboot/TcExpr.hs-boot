module TcExpr where
import RnHsSyn
import TcHsSyn
import TcRnTypes
import {-# SOURCE #-} TcType
import {-# SOURCE #-} TcUnify

tcCheckSigma :: 
	  RnHsSyn.RenamedHsExpr
       -> TcType.TcType
       -> TcRnTypes.TcM TcHsSyn.TcExpr

tcCheckRho :: 
	  RnHsSyn.RenamedHsExpr
       -> TcType.TcType
       -> TcRnTypes.TcM TcHsSyn.TcExpr

tcMonoExpr :: 
	  RnHsSyn.RenamedHsExpr
       -> TcUnify.Expected TcType.TcType
       -> TcRnTypes.TcM TcHsSyn.TcExpr
