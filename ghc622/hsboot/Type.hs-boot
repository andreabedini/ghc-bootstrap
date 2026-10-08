-- Hand-written (D22a pattern): PprType.hs-boot names Type.PredType while Type
-- SOURCE-imports PprType. PredType is a synonym in the real module, and mhs
-- does not reconcile a synonym with an abstract boot declaration (see the
-- InstEnv note in phase2/hsboot), so it is a synonym here too.
module Type where
import {-# SOURCE #-} TypeRep
type PredType = TypeRep.SourceType
