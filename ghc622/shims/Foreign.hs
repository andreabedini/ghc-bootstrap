-- Shadows ghc622/shims-ghc/Foreign.hs for the 6.2.2 tree. 4.08.2's compiler
-- wanted only ForeignObj from Foreign; 6.2.2's main/SysTools.lhs (its private
-- rawSystem, under __GLASGOW_HASKELL__ < 603) also imports
-- withMany, withArray0, nullPtr and Ptr, which are MicroHs's own.
module Foreign(module PrelForeign, module Foreign.Ptr,
               module Foreign.Marshal.Utils, module Foreign.Marshal.Array,
               module Foreign.Storable) where
import PrelForeign
import Foreign.Ptr
import Foreign.Marshal.Utils
import Foreign.Marshal.Array
import Foreign.Storable
