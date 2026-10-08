module Control.Monad.Reader(ReaderT(..), Reader, runReader, ask, asks, local,
                            module Control.Monad.Trans, module Control.Monad) where
import Control.Monad.Trans
import Control.Monad

newtype ReaderT r m a = ReaderT { runReaderT :: r -> m a }

type Reader r = ReaderT r Identity
newtype Identity a = Identity { runIdentity :: a }

instance Functor Identity where
  fmap f (Identity a) = Identity (f a)
instance Applicative Identity where
  pure = Identity
  Identity f <*> Identity a = Identity (f a)
instance Monad Identity where
  Identity a >>= k = k a

runReader :: Reader r a -> r -> a
runReader m r = runIdentity (runReaderT m r)

instance Functor m => Functor (ReaderT r m) where
  fmap f (ReaderT g) = ReaderT (\r -> fmap f (g r))

instance Applicative m => Applicative (ReaderT r m) where
  pure = ReaderT . const . pure
  ReaderT f <*> ReaderT g = ReaderT (\r -> f r <*> g r)

instance Monad m => Monad (ReaderT r m) where
  ReaderT g >>= k = ReaderT (\r -> g r >>= \a -> runReaderT (k a) r)

instance MonadTrans (ReaderT r) where
  lift m = ReaderT (const m)

-- Pre-MonadFail mtl put `fail` in the Monad class, and `Either e` used
-- `fail = Left . strMsg`. happy relies on it: `happyError = fail "Parse error"`
-- in a `ReaderT (String,Int) (Either String)`. Restoring those two instances
-- keeps the failure a `Left`, which is what happy's callers then match on.
instance MonadFail (Either String) where
  fail = Left

instance MonadFail m => MonadFail (ReaderT r m) where
  fail msg = ReaderT (\_ -> fail msg)

ask :: Monad m => ReaderT r m r
ask = ReaderT return

asks :: Monad m => (r -> a) -> ReaderT r m a
asks f = ReaderT (return . f)

local :: (r -> r) -> ReaderT r m a -> ReaderT r m a
local f (ReaderT g) = ReaderT (g . f)
