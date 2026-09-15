-- GHC 4.08's IO internals. The compiler only reaches in here to build IOErrors
-- and to get at a Handle's guts in FastString.hPutFS; the latter is replaced
-- wholesale (see FastString shim), so these are the error pieces plus enough
-- of the Handle types to satisfy signatures.
module PrelIOBase(IO, Handle, Handle__(..), IOError, IOErrorType(..),
                  IOResult(..), constructError, constructErrorAndFail,
                  fixIO, ioError, userError) where
import System.IO(Handle)
import System.IO.Error(ioError, userError)
import GhcCompat(fixIO)

data Handle__ = Handle__ Handle
data IOErrorType = AlreadyExists | NoSuchThing | ResourceBusy | ResourceExhausted
                 | EOF | IllegalOperation | PermissionDenied | UserError
                 | UnsatisfiedConstraints | SystemError | ProtocolError
                 | OtherError
data IOResult a = IOResult a

constructError :: String -> IO IOError
constructError s = return (userError s)

constructErrorAndFail :: String -> IO a
constructErrorAndFail s = ioError (userError s)

