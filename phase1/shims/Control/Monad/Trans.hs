-- The one class the three mtl shims share, defined once so that a module
-- importing two of them sees the same `lift`, not an ambiguous occurrence.
module Control.Monad.Trans(MonadTrans(..)) where

class MonadTrans t where
  lift :: Monad m => m a -> t m a
