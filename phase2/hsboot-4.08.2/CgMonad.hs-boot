-- Hand-written, same reason as DsUtils.hs-boot: CgUsages.hs-boot names
-- CgMonad.FCode while CgMonad SOURCE-imports CgUsages.
module CgMonad where

data CgInfoDownwards
data CgState
type FCode a = CgInfoDownwards -> CgState -> (a, CgState)
