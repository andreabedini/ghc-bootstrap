module RnSource where
import Outputable
import RdrHsSyn
import RnEnv
import RnHsSyn
import RnMonad

rnHsType :: Outputable.SDoc -> RdrHsSyn.RdrNameHsType -> RnMonad.RnMS (RnHsSyn.RenamedHsType, RnEnv.FreeVars)
rnHsSigType :: Outputable.SDoc -> RdrHsSyn.RdrNameHsType -> RnMonad.RnMS (RnHsSyn.RenamedHsType, RnEnv.FreeVars)
rnHsPolyType :: Outputable.SDoc -> RdrHsSyn.RdrNameHsType -> RnMonad.RnMS (RnHsSyn.RenamedHsType, RnEnv.FreeVars)
