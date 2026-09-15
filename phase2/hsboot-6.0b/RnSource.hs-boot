module RnSource where
import HsDecls
import {-# SOURCE #-} Name
import NameSet
import RdrHsSyn
import RdrName
import RnHsSyn
import TcRnTypes

rnBindsAndThen :: forall b . RdrHsSyn.RdrNameHsBinds
	-> (RnHsSyn.RenamedHsBinds
 	-> TcRnTypes.RnM (b, NameSet.FreeVars))
	-> TcRnTypes.RnM (b, NameSet.FreeVars) ;

rnBinds :: RdrHsSyn.RdrNameHsBinds
	-> TcRnTypes.RnM (RnHsSyn.RenamedHsBinds, NameSet.DefUses) ;

rnSrcDecls :: HsDecls.HsGroup RdrName.RdrName
	   -> TcRnTypes.RnM (TcRnTypes.TcGblEnv, HsDecls.HsGroup Name.Name, NameSet.DefUses)

