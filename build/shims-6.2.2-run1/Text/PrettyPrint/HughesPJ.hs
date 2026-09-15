-- Language.Haskell.THSyntax (from 6.0's libraries/haskell-src) wants the
-- HughesPJ pretty-printing library. MicroHs's lib has none; GHC's own
-- utils/Pretty.lhs is that library, so re-export it.
module Text.PrettyPrint.HughesPJ(module Pretty) where
import Pretty
