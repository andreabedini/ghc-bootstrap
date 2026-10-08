-- Haskell 98's IO module (ghc622/shims-h98/IO.hs re-exports MicroHs's
-- System.IO), plus what GHC 6.0's Binary.hs uses and MicroHs's System.IO lacks.
module IO(module System.IO, module System.IO.Error,
          hIsEOF, hSeek, hFileSize) where
import System.IO
import System.IO.Error

-- MicroHs has hLookAhead but no hIsEOF; the former fails with an EOF error
-- exactly when the latter would say True.
hIsEOF :: Handle -> IO Bool
hIsEOF h = (hLookAhead h >> return False) `catchIOError` \ e ->
  if isEOFError e then return True else ioError e

-- MicroHs handles cannot seek or report a size. Binary.hs only needs these
-- for its file-backed BinIO handles and for readBinMem, i.e. when interface
-- files are actually read or written, which compiling the compiler does not
-- exercise. Running it would need a seek/size primitive in MicroHs.
hSeek :: Handle -> SeekMode -> Integer -> IO ()
hSeek _ _ _ = ioError (userError "hSeek: MicroHs handles cannot seek")

hFileSize :: Handle -> IO Integer
hFileSize _ = ioError (userError "hFileSize: not available in MicroHs")
