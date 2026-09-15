-- Shim for hslibs' Posix, as far as GHC 6.0's compiler uses it under
-- __GLASGOW_HASKELL__ = 408: Panic.installSignalHandlers installs ^C and
-- SIGQUIT handlers that throw Interrupted to the main thread. Signal handling
-- is not needed to compile, so the handlers are accepted and never installed.
module Posix(Handler(..), Signal, SignalSet, installHandler, sigINT, sigQUIT) where

data Handler = Default | Ignore | Catch (IO ())

type Signal = Int
data SignalSet = SignalSet

sigINT, sigQUIT :: Signal
sigINT  = 2
sigQUIT = 3

installHandler :: Signal -> Handler -> Maybe SignalSet -> IO Handler
installHandler _ _ _ = return Default
