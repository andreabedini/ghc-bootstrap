-- StringBuffer, reimplemented over MicroHs's own facilities.
--
-- GHC 4.08's version is a malloc'd C buffer addressed by Addr#, read with
-- indexCharOffAddr#, filled by a hand-written slurp loop that calls read(2)
-- through _ccall_, and written through by unsafeWriteBuffer. None of that is
-- available on MicroHs, and it is the lexer's inner loop, so the representation
-- has to keep O(1) indexing: an immutable Data.Array of Char (backed by
-- Mhs.Array) rather than a String.
--
-- The semantics are copied from the original function by function, including
-- the NUL sentinel at the end of the buffer and the "EOB, return immediately"
-- special cases -- Lex.lhs depends on those exactly.
module StringBuffer(
  StringBuffer,
  hGetStringBuffer,
  currentChar, currentChar#, indexSBuffer, indexSBuffer#, lookAhead, lookAhead#,
  currentIndex#, lexemeIndex,
  setCurrentPos#, incLexeme, decLexeme,
  stepOn, stepOnBy#, stepOnTo#, stepOnUntil, stepOverLexeme,
  scanNumLit, squeezeLexeme, mergeLexemes,
  expandWhile, expandWhile#, expandUntilMatch,
  bufferExhausted, emptyLexeme,
  prefixMatch, untilEndOfString#, untilChar#,
  lexemeToString, lexemeToByteArray, lexemeToFastString, lexemeToBuffer,
  FastString, ByteArray,
  -- GHC 6.0 additions
  incCurrentPos, decCurrentPos, addToCurrentPos, stepOnUntilChar#,
  stringToStringBuffer, freeStringBuffer
  ) where

import Data.Array(Array, listArray, bounds, (!), elems)
import Data.Char(isDigit, ord)
import FastString(FastString, mkFastString)
import PrelArr(ByteArray(..))
import GlaExts(Char#, Int#)

--            contents      len  lexeme start  current
data StringBuffer = StringBuffer (Array Int Char) Int Int Int

instance Show StringBuffer where
  show sb = lexemeToString sb

-- Reading past the end yields the sentinel, as it does in the C buffer.
at :: StringBuffer -> Int -> Char
at (StringBuffer arr len _ _) i
  | i < 0 || i >= len = '\NUL'
  | otherwise         = arr ! i

-- GHC 6.0 dropped the expand_tabs argument (and the expansion).
hGetStringBuffer :: FilePath -> IO StringBuffer
hGetStringBuffer = hGetStringBufferT False

hGetStringBufferT :: Bool -> FilePath -> IO StringBuffer
hGetStringBufferT expand_tabs fname = do
  s <- readFile fname
  let s'  = if expand_tabs then expandTabs 0 s else s
      len = length s'
      -- one extra slot holds the NUL sentinel the original writes by hand
      arr = listArray (0, len) (s' ++ "\NUL")
  return (StringBuffer arr len 0 0)

expandTabs :: Int -> String -> String
expandTabs _ [] = []
expandTabs col ('\t':cs) = let n = 8 - (col `mod` 8)
                           in replicate n ' ' ++ expandTabs (col + n) cs
expandTabs _   ('\n':cs) = '\n' : expandTabs 0 cs
expandTabs col (c:cs)    = c : expandTabs (col + 1) cs

currentChar  :: StringBuffer -> Char
currentChar  sb@(StringBuffer _ _ _ c) = at sb c
currentChar# :: StringBuffer -> Char#
currentChar# = currentChar

indexSBuffer  :: StringBuffer -> Int -> Char
indexSBuffer  sb i = at sb i
indexSBuffer# :: StringBuffer -> Int# -> Char#
indexSBuffer# = indexSBuffer

lookAhead  :: StringBuffer -> Int -> Char
lookAhead  sb@(StringBuffer _ _ _ c) i = at sb (c + i)
lookAhead# :: StringBuffer -> Int# -> Char#
lookAhead# = lookAhead

currentIndex# :: StringBuffer -> Int#
currentIndex# (StringBuffer _ _ _ c) = c

lexemeIndex :: StringBuffer -> Int#
lexemeIndex (StringBuffer _ _ s _) = s

setCurrentPos# :: StringBuffer -> Int# -> StringBuffer
setCurrentPos# (StringBuffer a l s c) i = StringBuffer a l s (c + i)

incLexeme, decLexeme :: StringBuffer -> StringBuffer
incLexeme (StringBuffer a l s c) = StringBuffer a l s (c + 1)
decLexeme (StringBuffer a l s c) = StringBuffer a l s (c - 1)

stepOn :: StringBuffer -> StringBuffer
stepOn (StringBuffer a l s _) = StringBuffer a l (s + 1) (s + 1)

stepOnBy# :: StringBuffer -> Int# -> StringBuffer
stepOnBy# (StringBuffer a l s _) i = let n = s + i in StringBuffer a l n n

stepOnTo# :: StringBuffer -> Int# -> StringBuffer
stepOnTo# (StringBuffer a l _ _) s = StringBuffer a l s s

squeezeLexeme :: StringBuffer -> Int# -> StringBuffer
squeezeLexeme (StringBuffer a l s c) i = StringBuffer a l (s + i) c

mergeLexemes :: StringBuffer -> StringBuffer -> StringBuffer
mergeLexemes (StringBuffer a l s _) (StringBuffer _ _ _ c) = StringBuffer a l s c

stepOverLexeme :: StringBuffer -> StringBuffer
stepOverLexeme (StringBuffer a l _ c) = StringBuffer a l c c

stepOnUntil :: (Char -> Bool) -> StringBuffer -> StringBuffer
stepOnUntil p sb@(StringBuffer a l _ c0) = loop c0
  where loop c | p ch                        = StringBuffer a l c c
               | ch == '\NUL' && c >= l      = StringBuffer a l l l
               | otherwise                   = loop (c + 1)
          where ch = at sb c

expandWhile :: (Char -> Bool) -> StringBuffer -> StringBuffer
expandWhile p sb@(StringBuffer a l s c0) = loop c0
  where loop c | p ch                        = loop (c + 1)
               | ch == '\NUL' && c >= l      = StringBuffer a l l l
               | otherwise                   = StringBuffer a l s c
          where ch = at sb c

-- note: unlike expandWhile, the EOB case keeps the lexeme (as in the original)
expandWhile# :: (Char# -> Bool) -> StringBuffer -> StringBuffer
expandWhile# p sb@(StringBuffer a l s c0) = loop c0
  where loop c | p ch                        = loop (c + 1)
               | otherwise                   = StringBuffer a l s c
          where ch = at sb c

scanNumLit :: Integer -> StringBuffer -> (Integer, StringBuffer)
scanNumLit acc0 sb@(StringBuffer a l s c0) = loop acc0 c0
  where loop acc c
          | isDigit ch = loop (acc * 10 + toInteger (ord ch - ord '0')) (c + 1)
          | otherwise  = (acc, StringBuffer a l s c)
          where ch = at sb c

expandUntilMatch :: StringBuffer -> String -> Maybe StringBuffer
expandUntilMatch sb@(StringBuffer a l s c0) str = loop c0 str
  where loop c [] = Just (StringBuffer a l s c)
        loop c xxs@(x:xs)
          | ch == '\NUL' && c >= l = Nothing
          | ch == x                = loop (c + 1) xs
          | otherwise              = loop (c + 1) xxs
          where ch = at sb c

bufferExhausted :: StringBuffer -> Bool
bufferExhausted (StringBuffer _ l _ c) = c >= l

emptyLexeme :: StringBuffer -> Bool
emptyLexeme (StringBuffer _ _ s c) = s == c

prefixMatch :: StringBuffer -> String -> Maybe StringBuffer
prefixMatch sb@(StringBuffer a l s c0) str = loop c0 str
  where loop c [] = Just (StringBuffer a l s c)
        loop c (x:xs) | at sb c == x = loop (c + 1) xs
                      | otherwise    = Nothing

-- Scan to the closing quote of a string literal, honouring backslash escapes
-- by counting the run of backslashes before the quote, exactly as the original.
untilEndOfString# :: StringBuffer -> StringBuffer
untilEndOfString# sb@(StringBuffer a l s c0) = loop c0
  where
    loop c = case at sb c of
      '"'    -> case at sb (c - 1) of
                  '\\' -> if oddSlashes True (c - 2)
                          then loop (c + 1)          -- the quote was escaped
                          else StringBuffer a l s c
                  _    -> StringBuffer a l s c
      '\NUL' -> if c >= l then StringBuffer a l l l else loop (c + 1)
      _      -> loop (c + 1)
    oddSlashes flg i = case at sb i of
                         '\\' -> oddSlashes (not flg) (i - 1)
                         _    -> flg

untilChar# :: StringBuffer -> Char# -> StringBuffer
untilChar# sb@(StringBuffer a l s c0) x = loop c0
  where loop c | c >= l || at sb c == x = StringBuffer a l s c
               | otherwise              = loop (c + 1)

lexemeChars :: StringBuffer -> String
lexemeChars sb@(StringBuffer _ _ s c) = [at sb i | i <- [s .. c - 1]]

lexemeToString :: StringBuffer -> String
lexemeToString sb@(StringBuffer _ _ s c)
  | s == c    = ""
  | otherwise = lexemeChars sb

lexemeToByteArray :: StringBuffer -> ByteArray Int
lexemeToByteArray sb@(StringBuffer _ _ s c)
  | s == c    = error "lexemeToByteArray"
  | otherwise = ByteArray 0 (c - s - 1) (lexemeChars sb)

lexemeToFastString :: StringBuffer -> FastString
lexemeToFastString sb@(StringBuffer _ _ s c)
  | s == c    = mkFastString ""
  | otherwise = mkFastString (lexemeChars sb)

-- The original wrote a NUL over the last character of the shared buffer and
-- handed back a view of it. Here the lexeme is copied instead, which is what
-- the callers actually want and avoids mutating a buffer someone else holds.
lexemeToBuffer :: StringBuffer -> StringBuffer
lexemeToBuffer sb@(StringBuffer a l s c)
  | s == c    = StringBuffer a 0 s c
  | otherwise = let str = lexemeChars sb
                    n   = length str
                in StringBuffer (listArray (0, n) (str ++ "\NUL")) n 0 0

-- GHC 6.0 additions, over the same (contents, len, lexeme start, current)
-- representation.
incCurrentPos, decCurrentPos :: StringBuffer -> StringBuffer
incCurrentPos (StringBuffer a l s c) = StringBuffer a l s (c + 1)
decCurrentPos (StringBuffer a l s c) = StringBuffer a l s (c - 1)

addToCurrentPos :: StringBuffer -> Int# -> StringBuffer
addToCurrentPos (StringBuffer a l s c) i = StringBuffer a l s (c + i)

-- Advance the current position to the next occurrence of the character (or
-- the end of the buffer), as the C-pointer original does.
stepOnUntilChar# :: StringBuffer -> Char# -> StringBuffer
stepOnUntilChar# sb@(StringBuffer a l s c0) x = loop c0
  where loop c | c >= l || at sb c == x = StringBuffer a l c c
               | otherwise              = loop (c + 1)

stringToStringBuffer :: String -> IO StringBuffer
stringToStringBuffer str = do
  let len = length str
      arr = listArray (0, len) (str ++ "\NUL")
  return (StringBuffer arr len 0 0)

freeStringBuffer :: StringBuffer -> IO ()
freeStringBuffer _ = return ()
