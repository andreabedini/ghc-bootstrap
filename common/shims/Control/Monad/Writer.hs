module Control.Monad.Writer(Writer, WriterT(..), runWriter, execWriter, tell,
                            mapWriter, censor, listen, pass,
                            module Control.Monad.Trans, module Control.Monad) where
import Control.Monad.Trans
import Control.Monad

newtype WriterT w m a = WriterT { runWriterT :: m (a, w) }
newtype Writer w a = Writer { unWriter :: (a, w) }

runWriter :: Writer w a -> (a, w)
runWriter = unWriter

execWriter :: Writer w a -> w
execWriter = snd . unWriter

instance Functor (Writer w) where
  fmap f (Writer (a, w)) = Writer (f a, w)

instance Monoid w => Applicative (Writer w) where
  pure a = Writer (a, mempty)
  Writer (f, w1) <*> Writer (a, w2) = Writer (f a, w1 <> w2)

instance Monoid w => Monad (Writer w) where
  Writer (a, w1) >>= k = let Writer (b, w2) = k a in Writer (b, w1 <> w2)

tell :: w -> Writer w ()
tell w = Writer ((), w)

mapWriter :: ((a, w) -> (b, w')) -> Writer w a -> Writer w' b
mapWriter f (Writer aw) = Writer (f aw)

listen :: Writer w a -> Writer w (a, w)
listen (Writer (a, w)) = Writer ((a, w), w)

pass :: Writer w (a, w -> w) -> Writer w a
pass (Writer ((a, f), w)) = Writer (a, f w)

censor :: (w -> w) -> Writer w a -> Writer w a
censor f (Writer (a, w)) = Writer (a, f w)
