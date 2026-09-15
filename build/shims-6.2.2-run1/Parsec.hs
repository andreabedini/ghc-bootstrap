-- The slice of Parsec 1.x that GHC 6.0's genprimopcode uses, over a plain
-- backtracking parser. Parsec's (<|>) does not backtrack once the left branch
-- has consumed input; this one always does. On input the original parser
-- accepts, the two agree: every branch Parsec took succeeded, and a
-- first-success-wins choice takes the same branch.
module Parsec(
  Parser, ParseError, parse,
  (<|>), (<?>), try, pzero,
  satisfy, char, string, noneOf, oneOf, anyChar, lower, upper, letter, digit,
  many, many1, between, option, optional, eof, sepBy, skipMany,
  ) where

import Data.Char

newtype Parser a = P (String -> Either String (a, String))

newtype ParseError = ParseError String
instance Show ParseError where
  show (ParseError s) = s

runP :: Parser a -> String -> Either String (a, String)
runP (P f) = f

instance Functor Parser where
  fmap f p = P $ \ s -> case runP p s of
    Left e        -> Left e
    Right (a, s') -> Right (f a, s')

instance Applicative Parser where
  pure a  = P $ \ s -> Right (a, s)
  pf <*> pa = P $ \ s -> case runP pf s of
    Left e        -> Left e
    Right (f, s') -> case runP pa s' of
      Left e         -> Left e
      Right (a, s'') -> Right (f a, s'')

instance Monad Parser where
  p >>= k = P $ \ s -> case runP p s of
    Left e        -> Left e
    Right (a, s') -> runP (k a) s'

instance MonadFail Parser where
  fail msg = P $ \ _ -> Left msg

parse :: Parser a -> String -> String -> Either ParseError a
parse p _name s = case runP p s of
  Left e       -> Left (ParseError e)
  Right (a, _) -> Right a

infixr 1 <|>
infix  0 <?>

(<|>) :: Parser a -> Parser a -> Parser a
p <|> q = P $ \ s -> case runP p s of
  Left _ -> runP q s
  r      -> r

(<?>) :: Parser a -> String -> Parser a
p <?> name = P $ \ s -> case runP p s of
  Left _ -> Left ("expecting " ++ name)
  r      -> r

try :: Parser a -> Parser a
try = id

pzero :: Parser a
pzero = fail "pzero"

satisfy :: (Char -> Bool) -> Parser Char
satisfy ok = P $ \ s -> case s of
  (c:cs) | ok c -> Right (c, cs)
  _             -> Left "satisfy"

char :: Char -> Parser Char
char c = satisfy (== c) <?> show c

string :: String -> Parser String
string str = mapM char str <?> show str

noneOf, oneOf :: [Char] -> Parser Char
noneOf cs = satisfy (`notElem` cs)
oneOf  cs = satisfy (`elem` cs)

anyChar, lower, upper, letter, digit :: Parser Char
anyChar = satisfy (const True)
lower   = satisfy isLower
upper   = satisfy isUpper
letter  = satisfy isAlpha
digit   = satisfy isDigit

many :: Parser a -> Parser [a]
many p = many1 p <|> return []

many1 :: Parser a -> Parser [a]
many1 p = do { x <- p; xs <- many p; return (x:xs) }

skipMany :: Parser a -> Parser ()
skipMany p = many p >> return ()

between :: Parser o -> Parser c -> Parser a -> Parser a
between o c p = do { _ <- o; x <- p; _ <- c; return x }

option :: a -> Parser a -> Parser a
option d p = p <|> return d

optional :: Parser a -> Parser ()
optional p = (p >> return ()) <|> return ()

eof :: Parser ()
eof = P $ \ s -> if null s then Right ((), s) else Left "expecting end of input"

sepBy :: Parser a -> Parser sep -> Parser [a]
sepBy p sep = (do { x <- p; xs <- many (sep >> p); return (x:xs) }) <|> return []
