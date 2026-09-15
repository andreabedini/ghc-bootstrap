-- hslibs' Dynamic, which GHC 6.0's HsVersions.h names as DYNAMIC under
-- __GLASGOW_HASKELL__ < 504. MicroHs's Data.Dynamic covers what the compiler
-- uses (Typeable, toDyn, fromDynamic). MicroHs generates a Typeable instance
-- for every data type, so the one hand-written instance (Panic.GhcException,
-- via mkTyCon/mkAppTy) is removed by the Panic.lhs patch rather than shimmed.
module Dynamic(module Data.Dynamic, typeOf) where
import Data.Dynamic
import Data.Typeable(typeOf)
