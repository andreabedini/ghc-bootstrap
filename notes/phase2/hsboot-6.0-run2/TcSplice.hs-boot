module TcSplice where
import {-# SOURCE #-} HsExpr
import {-# SOURCE #-} Name
import RdrHsSyn
import RnHsSyn
import TcHsSyn
import TcRnTypes
import {-# SOURCE #-} TcType
import {-# SOURCE #-} TcUnify

tcSpliceExpr :: Name.Name
	     -> RnHsSyn.RenamedHsExpr
	     -> TcUnify.Expected TcType.TcType
	     -> TcRnTypes.TcM TcHsSyn.TcExpr

tcBracket :: HsExpr.HsBracket Name.Name 
	  -> TcUnify.Expected TcType.TcType
	  -> TcRnTypes.TcM TcHsSyn.TcExpr

tcSpliceDecls :: RnHsSyn.RenamedHsExpr 
	      -> TcRnTypes.TcM [RdrHsSyn.RdrNameHsDecl]

