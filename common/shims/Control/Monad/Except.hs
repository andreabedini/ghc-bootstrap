module Control.Monad.Except(ExceptT(..), Except, runExcept, throwError,
                            catchError, module Control.Monad.Trans, module Control.Monad) where
import Control.Monad.Trans
import Control.Monad

newtype ExceptT e m a = ExceptT { runExceptT :: m (Either e a) }

instance Functor m => Functor (ExceptT e m) where
  fmap f (ExceptT m) = ExceptT (fmap (fmap f) m)

instance Monad m => Applicative (ExceptT e m) where
  pure = ExceptT . return . Right
  ExceptT mf <*> ExceptT ma = ExceptT $ do
    ef <- mf
    case ef of
      Left e  -> return (Left e)
      Right f -> do
        ea <- ma
        return (case ea of { Left e -> Left e; Right a -> Right (f a) })

instance Monad m => Monad (ExceptT e m) where
  ExceptT m >>= k = ExceptT $ do
    ea <- m
    case ea of
      Left e  -> return (Left e)
      Right a -> runExceptT (k a)

instance MonadTrans (ExceptT e) where
  lift m = ExceptT (fmap Right m)

type Except e = ExceptT e Identity
newtype Identity a = Identity { runIdentity :: a }
instance Functor Identity where fmap f (Identity a) = Identity (f a)
instance Applicative Identity where
  pure = Identity
  Identity f <*> Identity a = Identity (f a)
instance Monad Identity where Identity a >>= k = k a

runExcept :: Except e a -> Either e a
runExcept = runIdentity . runExceptT

throwError :: Monad m => e -> ExceptT e m a
throwError = ExceptT . return . Left

catchError :: Monad m => ExceptT e m a -> (e -> ExceptT e m a) -> ExceptT e m a
catchError (ExceptT m) h = ExceptT $ do
  ea <- m
  case ea of { Left e -> runExceptT (h e); Right a -> return (Right a) }
