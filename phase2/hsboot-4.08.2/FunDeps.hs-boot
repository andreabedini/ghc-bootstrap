module FunDeps where
import Class
import Outputable
import Pretty
import UniqFM
import Unique

instantiateFdClassTys :: forall b . Class.Class -> [b] -> [([b], [b])]
oclose :: forall a . (Unique.Uniquable a) => [([a], [a])] -> UniqFM.UniqFM a -> UniqFM.UniqFM a
pprFundeps :: forall a a1 . (Outputable.Outputable a) => (Outputable.Outputable a1) => [([a], [a1])] -> Outputable.PprStyle -> Pretty.Doc
