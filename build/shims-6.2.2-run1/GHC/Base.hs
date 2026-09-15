-- The one thing GHC 6.0's TcSplice takes from GHC.Base. mhs accepts
-- MagicHash names and has a real unsafeCoerce, so this is a rename (as
-- phase1/shims/GHC/Exts.hs does for happy).
module GHC.Base(unsafeCoerce#) where
import Unsafe.Coerce(unsafeCoerce)

unsafeCoerce# :: a -> b
unsafeCoerce# = unsafeCoerce
