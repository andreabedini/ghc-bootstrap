-- Haskell 98's IO module (phase1/shims-h98/IO.hs re-exports MicroHs's
-- System.IO), plus what GHC 6.0's Binary.hs uses and MicroHs's System.IO lacks.
-- System.IO.Error is listed by name rather than re-exported as a module:
-- mhs ignores `hiding` on a `module M` export, and its IOErrorType
-- constructor Interrupted (which Haskell 98's IO never exposed) would
-- otherwise collide with Panic's GhcException constructor in Main.hs and
-- InteractiveUI.hs, which import IO unqualified. IOErrorType stays abstract.
module IO(module System.IO,
          IOException(..), ioException, IOError, IOErrorType, userError,
          mkIOError, annotateIOError,
          isAlreadyExistsError, isDoesNotExistError, isAlreadyInUseError,
          isFullError, isEOFError, isIllegalOperation, isPermissionError,
          isUserError, isResourceVanishedError,
          ioeGetErrorType, ioeGetLocation, ioeGetErrorString, ioeGetHandle,
          ioeGetFileName, ioeSetErrorType, ioeSetErrorString, ioeSetLocation,
          ioeSetHandle, ioeSetFileName,
          alreadyExistsErrorType, doesNotExistErrorType, alreadyInUseErrorType,
          fullErrorType, eofErrorType, illegalOperationErrorType,
          permissionErrorType, userErrorType, resourceVanishedErrorType,
          isAlreadyExistsErrorType, isDoesNotExistErrorType,
          isAlreadyInUseErrorType, isFullErrorType, isEOFErrorType,
          isIllegalOperationErrorType, isPermissionErrorType, isUserErrorType,
          isResourceVanishedErrorType,
          hIsEOF, hSeek, hFileSize, catch, try, bracket, bracket_) where
import Control.Exception(bracket, bracket_)   -- Haskell 98's IO exported these
import System.IO
import System.IO.Error
import GhcCompat(catch)

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

-- Haskell 98's IO.catch is the same entity as Prelude.catch. HsVersions.h
-- brings GhcCompat.catch into every module, so this must be that entity too,
-- or any module importing IO unqualified sees two catches.

-- Haskell 98's IO.try.
try :: IO a -> IO (Either IOError a)
try = tryIOError
