-- hslibs' IOExts: mutable references, unsafePerformIO, trace, and the two
-- lazy-IO operations TcMonad uses to tie its knot.
module IOExts(module Data.IORef, unsafePerformIO, unsafeInterleaveIO,
              fixIO, trace,
              -- hslibs additions GHC 6.0's Binary.hs relies on
              IOModeEx(..), openFileEx) where
import Data.IORef
import System.IO(Handle, IOMode, openBinaryFile, openFile)
import System.IO.Unsafe(unsafePerformIO, unsafeInterleaveIO)
import GhcCompat(fixIO)
import Debug.Trace(trace)

-- hslibs' binary-mode file opening. Text and binary mode coincide on POSIX,
-- which is the only place this chain runs.
data IOModeEx = BinaryMode IOMode | TextMode IOMode

openFileEx :: FilePath -> IOModeEx -> IO Handle
openFileEx f (BinaryMode m) = openBinaryFile f m
openFileEx f (TextMode m)   = openFile f m
