{-# OPTIONS -fno-implicit-prelude #-}
module FmtCheck where
import GHC.Base
data T = A | B
f :: T -> T
f A = B
f B = A
g :: T -> Bool
g A = True
g B = False
