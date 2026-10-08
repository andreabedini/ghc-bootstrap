-- StringBuffer for GHC 6.2.2, reimplemented over MicroHs's own facilities.
--
-- 6.2.2 replaced the old Addr#-based module with a ByteArray# plus a cursor and
-- shrank the API to the eleven functions below (Lexer.x, ParsePkgConf.y,
-- HscMain and RnHiFiles use nothing else).  MicroHs has no ByteArray#, so the
-- bytes live in an immutable Data.Array of Char, which keeps the O(1) indexing
-- the lexer's inner loop needs.
--
-- Semantics are copied function by function from utils/StringBuffer.lhs:
--   * there is no NUL sentinel any more; the lexer tests atEnd explicitly
--   * the buffer holds *bytes* (the original reads with openBinaryFile and
--     stringToStringBuffer truncates each Char to Word8), so a Char here is
--     always in 0..255 -- Lexer's alex tables are indexed by ord of it
--   * currentChar/lookAhead ASSERTed their index in range; here an
--     out-of-range read returns '\NUL' instead of a crash (debug builds
--     would have panicked, non-debug builds read past the array)
module StringBuffer(
        StringBuffer,

         -- * Creation/destruction
        hGetStringBuffer,     -- :: FilePath     -> IO StringBuffer
        stringToStringBuffer, -- :: String       -> IO StringBuffer

         -- * Lookup
        currentChar,       -- :: StringBuffer -> Char
        prevChar,          -- :: StringBuffer -> Char -> Char
        lookAhead,         -- :: StringBuffer -> Int  -> Char
        atEnd,             -- :: StringBuffer -> Bool
        difference,        -- :: StringBuffer -> StringBuffer -> Int

        -- * Moving
        stepOn, stepOnBy,

         -- * Conversion
        lexemeToString,     -- :: StringBuffer -> Int -> String
        lexemeToFastString, -- :: StringBuffer -> Int -> FastString
       ) where

import Data.Array(Array, listArray, (!))
import Data.Char(chr, ord)
import qualified Data.ByteString as B
import FastString(FastString, mkFastString)

-- -----------------------------------------------------------------------------
-- The StringBuffer type

--                                 contents        length  current pos
data StringBuffer = StringBuffer !(Array Int Char) !Int    !Int

instance Show StringBuffer where
        showsPrec _ s = showString "<stringbuffer>"

-- -----------------------------------------------------------------------------
-- Creation / Destruction

hGetStringBuffer :: FilePath -> IO StringBuffer
hGetStringBuffer fname = do
   bs <- B.readFile fname                      -- bytes, as openBinaryFile gave
   return (fromChars (map (chr . fromIntegral) (B.unpack bs)))

stringToStringBuffer :: String -> IO StringBuffer
stringToStringBuffer str =
   return (fromChars (map (chr . (`mod` 256) . ord) str))   -- fromIntegral.ord :: Word8

fromChars :: String -> StringBuffer
fromChars s = StringBuffer (listArray (0, size - 1) s) size 0
  where size = length s

-- -----------------------------------------------------------------------------
-- Lookup

currentChar  :: StringBuffer -> Char
currentChar (StringBuffer arr l current)
  | current >= 0 && current < l = arr ! current
  | otherwise                   = '\NUL'

prevChar :: StringBuffer -> Char -> Char
prevChar (StringBuffer _ _ 0) deflt = deflt
prevChar s deflt = lookAhead s (-1)

lookAhead :: StringBuffer -> Int  -> Char
lookAhead (StringBuffer arr l c) i
  | off >= 0 && off < l = arr ! off
  | otherwise           = '\NUL'
 where
   off = c + i

difference :: StringBuffer -> StringBuffer -> Int
difference (StringBuffer _ _ c1) (StringBuffer _ _ c2) = c2 - c1

-- -----------------------------------------------------------------------------
-- Moving

stepOn :: StringBuffer -> StringBuffer
stepOn s = stepOnBy 1 s

stepOnBy :: Int -> StringBuffer -> StringBuffer
stepOnBy i (StringBuffer fo l c) = StringBuffer fo l (c + i)

atEnd :: StringBuffer -> Bool
atEnd (StringBuffer _ l c) = l == c

-- -----------------------------------------------------------------------------
-- Conversion

lexemeToString :: StringBuffer -> Int -> String
lexemeToString _ 0 = ""
lexemeToString (StringBuffer arr _ current) len = unpack current
 where
    end = current + len

    unpack nh
      | nh >= end  = []
      | otherwise  = arr ! nh : unpack (nh + 1)

lexemeToFastString :: StringBuffer -> Int -> FastString
lexemeToFastString _ 0 = mkFastString ""
lexemeToFastString buf len = mkFastString (lexemeToString buf len)
