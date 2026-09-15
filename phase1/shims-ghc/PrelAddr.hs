-- GHC 4.08's boxed address type. Addr# is a real Ptr (see GlaExts), so these
-- can point at genuine memory rather than being a placeholder.
module PrelAddr(Addr(..), Word(..), intToWord, wordToInt, nullAddr) where
import GlaExts(Addr#)
import Data.Word(Word)
import Foreign.Ptr(nullPtr)

data Addr = A# Addr#

nullAddr :: Addr
nullAddr = A# nullPtr

intToWord :: Int -> Word
intToWord = fromIntegral
wordToInt :: Word -> Int
wordToInt = fromIntegral
