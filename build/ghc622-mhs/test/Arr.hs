module Main where
import Data.Array
import Data.Bits
import Data.Word
import Data.Int
import Data.Char
import qualified Data.FiniteMap as FM
import Text.Read
import Data.Maybe
main :: IO ()
main = do
  let a = listArray (0, 9) [i * i | i <- [0 .. 9]] :: Array Int Int
  print (a ! 7, bounds a, sum (elems a))
  let fibs = listArray (0, 50) [if i < 2 then toInteger i else fibs ! (i-1) + fibs ! (i-2) | i <- [0 .. 50]] :: Array Int Integer
  print (fibs ! 50)
  print (accumArray (+) 0 (0, 3) [(i `mod` 4, i) | i <- [1 .. 100]] :: Array Int Int)
  print (255 + 1 :: Word8, 127 + 1 :: Int8, maxBound :: Word64, minBound :: Int64, (-1) :: Word32)
  print (shiftL 1 40 :: Int, testBit (0xff00ff :: Word32) 16, complement 0 :: Word16, xor 5 3 :: Int)
  print (ord 'a', chr 955, isAlpha 'x', toUpper 'q', show "tab\there\955")
  let fm = FM.listToFM [(k, length k) | k <- words "the quick brown fox jumps over the lazy dog"]
  print (FM.fmToList fm)
  print (FM.lookupFM fm "fox", FM.sizeFM fm)
  print (reads "17 rest" :: [(Int, String)])
  print (fromJust (lookup 3 (zip [1 ..] "abcdef")))
