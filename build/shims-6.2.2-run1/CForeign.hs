-- GHC 6.2.2's main/SysTools.lhs imports CForeign (CString, withCString,
-- throwErrnoIfMinus1) under __GLASGOW_HASKELL__ < 603, which is the branch
-- our -D__GLASGOW_HASKELL__=408 takes. hslibs' CForeign was the flat name for
-- what is now Foreign.C; MicroHs has the latter.
module CForeign(module Foreign.C) where
import Foreign.C
