module Addr(module PrelAddr, indexAddrOffAddr, plusAddr) where
import PrelAddr
import GlaExts(Addr#)
import Foreign.Ptr(plusPtr)

indexAddrOffAddr :: Addr -> Int -> Addr
indexAddrOffAddr (A# a) n = A# (plusPtr a n)

plusAddr :: Addr -> Int -> Addr
plusAddr = indexAddrOffAddr
