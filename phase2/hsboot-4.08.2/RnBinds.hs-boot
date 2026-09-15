module RnBinds where
import RdrHsSyn
import RnEnv
import RnHsSyn
import RnMonad

rnBinds :: forall b . RdrHsSyn.RdrNameHsBinds -> (RnHsSyn.RenamedHsBinds -> RnMonad.RnMS (b, RnEnv.FreeVars)) -> RnMonad.RnMS (b, RnEnv.FreeVars)
