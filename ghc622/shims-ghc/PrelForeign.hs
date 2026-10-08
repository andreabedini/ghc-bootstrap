-- GHC 4.08's ForeignObj: a finalised pointer. Nothing in the compiler's own
-- source dereferences one; they are only carried around.
module PrelForeign(ForeignObj(..), ForeignObj#) where
import GlaExts(Addr#)
type ForeignObj# = Addr#
data ForeignObj = ForeignObj ForeignObj#
