-- hslibs' Concurrent, which GHC 6.0's HsVersions.h names as CONCURRENT under
-- __GLASGOW_HASKELL__ < 504. MicroHs's Control.Concurrent has the names the
-- compiler uses (myThreadId, throwTo).
module Concurrent(module Control.Concurrent) where
import Control.Concurrent
