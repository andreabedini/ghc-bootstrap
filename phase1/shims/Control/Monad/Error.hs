-- mtl's pre-Except name. happy 1.19.5 uses ErrorT/runErrorT/throwError only.
module Control.Monad.Error(ErrorT(..), Error(..), throwError, catchError,
                           module Control.Monad.Trans, module Control.Monad) where
import Control.Monad.Trans
import Control.Monad

class Error e where
  noMsg  :: e
  noMsg = strMsg ""
  strMsg :: String -> e
  strMsg _ = noMsg

instance Error String where
  strMsg = id

newtype ErrorT e m a = ErrorT { runErrorT :: m (Either e a) }

instance Functor m => Functor (ErrorT e m) where
  fmap f (ErrorT m) = ErrorT (fmap (fmap f) m)

instance Monad m => Applicative (ErrorT e m) where
  pure = ErrorT . return . Right
  ErrorT mf <*> ErrorT ma = ErrorT $ do
    ef <- mf
    case ef of
      Left e  -> return (Left e)
      Right f -> do
        ea <- ma
        return (case ea of { Left e -> Left e; Right a -> Right (f a) })

instance Monad m => Monad (ErrorT e m) where
  ErrorT m >>= k = ErrorT $ do
    ea <- m
    case ea of { Left e -> return (Left e); Right a -> runErrorT (k a) }

instance MonadTrans (ErrorT e) where
  lift m = ErrorT (fmap Right m)

throwError :: Monad m => e -> ErrorT e m a
throwError = ErrorT . return . Left

catchError :: Monad m => ErrorT e m a -> (e -> ErrorT e m a) -> ErrorT e m a
catchError (ErrorT m) h = ErrorT $ do
  ea <- m
  case ea of { Left e -> runErrorT (h e); Right a -> return (Right a) }
