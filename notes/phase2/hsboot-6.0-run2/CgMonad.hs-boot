-- Hand-written (D22a pattern): CgUsages.hs-boot and CgExpr.hs-boot name
-- CgMonad.FCode / CgMonad.Code while CgMonad SOURCE-imports CgUsages.
module CgMonad where
data CgInfoDownwards
data CgState
newtype FCode a = FCode (CgInfoDownwards -> CgState -> (a, CgState))
type Code = FCode ()
