-- Only FastString.hPutFS used these, and that module is replaced.
module PrelHandle(module PrelIOBase, readHandle, writeHandle, filePtr) where
import PrelIOBase
import GlaExts(Addr#)
import Foreign.Ptr(nullPtr)

readHandle, writeHandle :: Handle -> IO Handle__
readHandle  = return . Handle__
writeHandle = return . Handle__

filePtr :: Handle__ -> Addr#
filePtr _ = nullPtr
