-- Hand-written, not generated from a .hi-boot: GHC 4.08.2 has no Type.hi-boot
-- because its interface-based boot files can name Type.PredType without
-- creating a build edge. mhs's .hs-boot files are real modules, so
-- PprType.hs-boot's reference to PredType would import Type and re-form the
-- cycle Type -SOURCE-> PprType -> Type. Declaring PredType abstractly here
-- lets PprType.hs-boot SOURCE-import Type instead.
module Type where
import {-# SOURCE #-} TypeRep

data PredType
