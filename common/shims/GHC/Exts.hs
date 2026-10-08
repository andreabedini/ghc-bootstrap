-- The sliver of GHC.Exts that portable-template happy needs. mhs accepts
-- MagicHash identifiers and has a real unsafeCoerce, so this is a rename.
module GHC.Exts(unsafeCoerce#) where
import Unsafe.Coerce(unsafeCoerce)

unsafeCoerce# :: a -> b
unsafeCoerce# = unsafeCoerce
