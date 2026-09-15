-- hslibs' IOExts: mutable references, unsafePerformIO, trace, and the two
-- lazy-IO operations TcMonad uses to tie its knot.
module IOExts(module Data.IORef, unsafePerformIO, unsafeInterleaveIO,
              fixIO, trace) where
import Data.IORef
import System.IO.Unsafe(unsafePerformIO, unsafeInterleaveIO)
import GhcCompat(fixIO)
import Debug.Trace(trace)
