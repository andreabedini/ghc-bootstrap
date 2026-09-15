-- Hand-written. Match.hs-boot references DsUtils.EquationInfo and
-- DsUtils.MatchResult, and DsUtils SOURCE-imports Match -- so a plain import of
-- DsUtils from the boot file re-forms the cycle the boot exists to break.
-- Giving DsUtils its own boot lets Match.hs-boot SOURCE-import it instead.
-- GHC needed none of this: its .hi-boot files are interfaces and name types in
-- other modules without creating build edges.
module DsUtils where

data EquationInfo
data MatchResult
