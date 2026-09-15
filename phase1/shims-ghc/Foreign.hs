-- GHC 4.08's hslibs Foreign, not the modern one: the compiler wants ForeignObj.
module Foreign(module PrelForeign) where
import PrelForeign
