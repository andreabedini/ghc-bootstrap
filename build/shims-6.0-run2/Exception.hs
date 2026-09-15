-- hslibs' Exception (GHC 4.08 / 5.x), which GHC 6.0's HsVersions.h names as
-- EXCEPTION under __GLASGOW_HASKELL__ < 504, reimplemented over MicroHs's
-- Control.Exception. The old API has one closed Exception type whose
-- constructors the compiler pattern-matches on (DynException, AssertionFailed,
-- IOException, ...); the modern API is open (SomeException + a class). This
-- shim provides the closed type, converting at the catch sites, and the 4.08
-- names tryIO/tryAllIO/catchIO/catchAllIO/raiseInThread the tree still uses.
--
-- Surface is exactly what ghc-6.0/ghc/compiler uses (17 modules).
module Exception(
  Exception(..),
  AsyncException(..),   -- Main.hs matches AsyncException StackOverflow
  throw, throwDyn, raiseInThread,
  catch, catchDyn, catchIO, catchAllIO,
  try, tryIO, tryAllIO,
  justIoErrors,
  bracket, finally, unblock,
  -- catchJust, tryJust, ioErrors and throwTo are deliberately NOT exported:
  -- 4.08's hslibs Exception lacked them, and Panic.lhs's <= 408 block defines
  -- them itself (catchJust = catchIO, ...). Exporting them here makes every
  -- module that imports both Panic and EXCEPTION unqualified ambiguous.
  ) where

import Prelude hiding (catch)
import qualified Control.Exception as E
import Control.Exception (AsyncException(..))
import Control.Concurrent(ThreadId)
import qualified Control.Concurrent as C
import Data.Dynamic(Dynamic, Typeable, toDyn, fromDynamic)
import System.IO.Error(IOError)

data Exception
  = IOException      IOError
  | ArithException   E.ArithException
  | ErrorCall        String
  | AssertionFailed  String
  | AsyncException   E.AsyncException
  | DynException     Dynamic
  | OtherException   E.SomeException   -- anything the old type had no case for

instance Show Exception where
  showsPrec _ (IOException e)     = shows e
  showsPrec _ (ArithException e)  = shows e
  showsPrec _ (ErrorCall s)       = showString s
  showsPrec _ (AssertionFailed s) = showString "Assertion failed: " . showString s
  showsPrec _ (AsyncException e)  = shows e
  showsPrec _ (DynException _)    = showString "unknown exception"
  showsPrec _ (OtherException e)  = shows e

instance E.Exception Exception

-- Classify a caught SomeException into the closed type.
fromSome :: E.SomeException -> Exception
fromSome se
  | Just (e :: Exception)         <- E.fromException se = e
  | Just (e :: IOError)           <- E.fromException se = IOException e
  | Just (e :: E.ArithException)  <- E.fromException se = ArithException e
  | Just (E.ErrorCall s)          <- E.fromException se = ErrorCall s
  | Just (e :: E.AsyncException)  <- E.fromException se = AsyncException e
  | otherwise                                            = OtherException se

throw :: Exception -> a
throw = E.throw

throwDyn :: Typeable e => e -> b
throwDyn e = E.throw (DynException (toDyn e))

throwTo :: ThreadId -> Exception -> IO ()
throwTo = C.throwTo

raiseInThread :: ThreadId -> Exception -> IO ()
raiseInThread = throwTo

catch :: IO a -> (Exception -> IO a) -> IO a
catch act h = act `E.catch` \ se -> h (fromSome se)

catchDyn :: Typeable e => IO a -> (e -> IO a) -> IO a
catchDyn act h = act `catch` \ ex -> case ex of
  DynException d | Just e <- fromDynamic d -> h e
  _ -> throw ex

catchJust :: (Exception -> Maybe b) -> IO a -> (b -> IO a) -> IO a
catchJust p act h = act `catch` \ ex -> case p ex of
  Just b  -> h b
  Nothing -> throw ex

-- In 4.08.2's hslibs (hslibs/lang/Exception.lhs:107,134) catchIO and tryIO
-- have the catchJust/tryJust shapes; Panic.lhs's <= 408 block relies on that.
catchIO :: (Exception -> Maybe b) -> IO a -> (b -> IO a) -> IO a
catchIO = catchJust

catchAllIO :: IO a -> (Exception -> IO a) -> IO a
catchAllIO = catch

try :: IO a -> IO (Either Exception a)
try act = (Right `fmap` act) `catch` (return . Left)

tryJust :: (Exception -> Maybe b) -> IO a -> IO (Either b a)
tryJust p act = do
  r <- try act
  case r of
    Right v -> return (Right v)
    Left ex -> case p ex of
      Just b  -> return (Left b)
      Nothing -> throw ex

tryIO :: (Exception -> Maybe b) -> IO a -> IO (Either b a)
tryIO = tryJust

tryAllIO :: IO a -> IO (Either Exception a)
tryAllIO = try

ioErrors, justIoErrors :: Exception -> Maybe IOError
ioErrors (IOException e) = Just e
ioErrors _               = Nothing
justIoErrors = ioErrors

bracket :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
bracket = E.bracket

finally :: IO a -> IO b -> IO a
finally = E.finally

-- Asynchronous exceptions are never blocked here.
unblock :: IO a -> IO a
unblock = id
