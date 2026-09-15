module TcMatches where
import {-# SOURCE #-} Name
import RnHsSyn
import TcHsSyn
import TcMonad
import {-# SOURCE #-} TcType

tcGRHSsPat :: forall s . RnHsSyn.RenamedGRHSs -> TcType.TcType -> TcMonad.TcM s (TcHsSyn.TcGRHSs, TcMonad.LIE)
tcMatchesFun :: forall s . Name.Name -> TcType.TcType -> [RnHsSyn.RenamedMatch] -> TcMonad.TcM s ([TcHsSyn.TcMatch], TcMonad.LIE)
