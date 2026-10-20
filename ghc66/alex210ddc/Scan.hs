-------------------------------------------------------------------------------
-- Scan.hs for alex 2.1.0, written by hand: no alex made any of this file.
--
-- It replaces the src/Scan.hs that alex 2.1.0's tarball ships, which is
-- alex's own output on src/Scan.x. The export list, the Token and Tkn types
-- and everything from "Token type" down are Scan.x's own Haskell, copied
-- as they are (alex copies them into its output the same way), but for one
-- edit for mhs: `not.isSpace` is spaced to `not . isSpace`, since MicroHs
-- reads `a.b` as a record field selection. What alex would generate, the
-- DFA tables and the template's alexScan, is replaced by the part above
-- that line: each macro and rule of Scan.x written out as a regular
-- expression over the combinators below, and alexScan taking the longest
-- match, the earlier rule winning a tie, as alex's DFA does.
--
-- Character sets follow alex 2.1.0: the predefined $white, $printable and .
-- are Main.hs's initSetEnv, [^ s] is . minus s (Parser.y), and sets range
-- over '\0'..'\xff' (CharSet.charSetToArray), so . stops there too.
-------------------------------------------------------------------------------

module Scan(lexer, AlexPosn(..), Token(..), Tkn(..), tokPosn) where

import Data.Char
import ParseMonad

-- -----------------------------------------------------------------------------
-- Regular expressions

-- A regular expression is the list of the ways it matches a prefix of the
-- input: how many characters each one takes, and the input after them.
-- Characters are taken with ParseMonad's alexGetChar, which moves the
-- position as alex's generated scanner does.
type RE = AlexInput -> [(Int, AlexInput)]

-- one character in the set
set :: (Char -> Bool) -> RE
set p inp = case alexGetChar inp of
              Just (c, inp') | p c -> [(1, inp')]
              _                    -> []

ch :: Char -> RE
ch c = set (== c)

-- a string of characters, "..." in Scan.x
str :: String -> RE
str s = foldr (\c r -> ch c <.> r) eps s

-- the empty pattern, () in Scan.x
eps :: RE
eps inp = [(0, inp)]

infixr 5 <|>
infixr 6 <.>

(<.>) :: RE -> RE -> RE
(r <.> s) inp = [ (m + n, inp'') | (m, inp') <- r inp, (n, inp'') <- s inp' ]

(<|>) :: RE -> RE -> RE
(r <|> s) inp = r inp ++ s inp

star, plus, opt :: RE -> RE
star r = eps <|> plus r
plus r = r <.> star r
opt r  = eps <|> r

-- -----------------------------------------------------------------------------
-- Character sets: alex 2.1.0's predefined ones (Main.hs, initSetEnv)

inRange' :: Char -> Char -> Char -> Bool
inRange' lo hi c = c >= lo && c <= hi

white, printable, dot :: Char -> Bool
white c     = c `elem` " \t\n\v\f\r"
printable   = inRange' (chr 32) (chr 126)
dot c       = c /= '\n' && c <= '\xff'

-- [^ s]
notIn :: (Char -> Bool) -> Char -> Bool
notIn s c = dot c && not (s c)

-- -----------------------------------------------------------------------------
-- Scan.x's macros

-- $digit    = 0-9
-- $hexdig   = [0-9 A-F a-f]
-- $octal    = 0-7
-- $lower    = a-z
-- $upper    = A-Z
-- $alpha    = [$upper $lower]
-- $alphanum = [$alpha $digit]
-- $idchar   = [$alphanum \_ \']
digit, hexdig, octal, lower, upper, alpha, alphanum, idchar :: Char -> Bool
digit      = inRange' '0' '9'
hexdig c   = digit c || inRange' 'A' 'F' c || inRange' 'a' 'f' c
octal      = inRange' '0' '7'
lower      = inRange' 'a' 'z'
upper      = inRange' 'A' 'Z'
alpha c    = upper c || lower c
alphanum c = alpha c || digit c
idchar c   = alphanum c || c == '_' || c == '\''

-- $special    = [\.\;\,\$\|\*\+\?\#\~\-\{\}\(\)\[\]\^\/]
-- $graphic    = $printable # $white
-- $nonspecial = $graphic # [$special \%]
special', graphic, nonspecial :: Char -> Bool
special' c   = c `elem` ".;,$|*+?#~-{}()[]^/"
graphic c    = printable c && not (white c)
nonspecial c = graphic c && not (special' c || c == '%')

-- @id     = $alpha $idchar*
-- @smac   = \$ @id | \$ \{ @id \}
-- @rmac   = \@ @id | \@ \{ @id \}
-- @comment = "--".*
-- @ws      = $white+ | @comment
ident, smac', rmac', comment, ws :: RE
ident   = set alpha <.> star (set idchar)
smac'   = ch '$' <.> ident <|> ch '$' <.> ch '{' <.> ident <.> ch '}'
rmac'   = ch '@' <.> ident <|> ch '@' <.> ch '{' <.> ident <.> ch '}'
comment = str "--" <.> star (set dot)
ws      = plus (set white) <|> comment

-- -----------------------------------------------------------------------------
-- Scan.x's rules, in order: the start codes a rule applies in (a rule with
-- none applies in all of them), its pattern and its action.

-- the start codes Scan.x names; 0 is ParseMonad's initial one
afterstartcodes, startcodes :: Int
afterstartcodes = 1
startcodes = 2

data Rule = Rule (StartCode -> Bool) RE Action

anySC :: StartCode -> Bool
anySC _ = True

sc :: StartCode -> StartCode -> Bool
sc = (==)

rules :: [Rule]
rules =
  [ Rule anySC  ws                                        skip      -- @ws

  , Rule (sc 0) (ch '"' <.> star (set (notIn (== '"'))) <.> ch '"')
                                                          string    -- \" [^\"]* \"
  , Rule (sc 0) (opt (ident <.> opt ws) <.> ch ':' <.> ch '-')
                                                          bind      -- (@id @ws?)? \:\-
  , Rule (sc 0) (ch '{' <.> (ch '\n' <|> set (notIn digit)))
                                                          code      -- \{ (\n | [^$digit])
  , Rule (sc 0) (set special')                            special   -- $special
  , Rule (sc 0) (ch '%' <.> str "wrapper")                wrapper   -- \% "wrapper"

  , Rule (sc 0) (ch '\\' <.> plus (set digit))            decch     -- \\ $digit+
  , Rule (sc 0) (ch '\\' <.> ch 'x' <.> plus (set hexdig)) hexch    -- \\ x $hexdig+
  , Rule (sc 0) (ch '\\' <.> ch 'o' <.> plus (set octal)) octch     -- \\ o $octal+
  , Rule (sc 0) (ch '\\' <.> set printable)               escape    -- \\ $printable
  , Rule (sc 0) (set (\c -> nonspecial c && c /= '<'))    char      -- $nonspecial # [\<]
  , Rule (sc 0) smac'                                     smac      -- @smac
  , Rule (sc 0) rmac'                                     rmac      -- @rmac

  , Rule (sc 0) (smac' <.> opt ws <.> ch '=')             smacdef   -- @smac @ws? \=
  , Rule (sc 0) (rmac' <.> opt ws <.> ch '=')             rmacdef   -- @rmac @ws? \=

  , Rule (sc 0) (ch '<')                  (special `andBegin` startcodes)  -- \<
  , Rule (sc startcodes) (ch '0')                         zero      -- 0
  , Rule (sc startcodes) ident                            startcode -- @id
  , Rule (sc startcodes) (ch ',')                         special   -- \,
  , Rule (sc startcodes) (ch '>')         (special `andBegin` afterstartcodes)  -- \>

  , Rule (sc afterstartcodes) (ch '{' <.> (ch '\n' <|> set (notIn (\c -> digit c || c == ' '))))
                                          (special `andBegin` 0)    -- \{ (\n | [^$digit ])
  , Rule (sc afterstartcodes) eps         (skip `andBegin` 0)       -- ()
  ]

-- -----------------------------------------------------------------------------
-- alexScan: what alex's template provides, here by trying every rule

data AlexReturn a
  = AlexEOF
  | AlexError  AlexInput
  | AlexSkip   AlexInput Int
  | AlexToken  AlexInput Int a

-- The longest match of any rule that applies in the start code; of rules
-- matching the same length, the first. No match is the end of the input
-- if there is none left, an error otherwise.
alexScan :: AlexInput -> StartCode -> AlexReturn Action
alexScan inp s =
  case longest [ (n, inp', act) | Rule ok re act <- rules, ok s, (n, inp') <- re inp ] of
    Just (n, inp', act) -> AlexToken inp' n act
    Nothing -> case alexGetChar inp of
                 Nothing -> AlexEOF
                 Just _  -> AlexError inp
 where
  longest []       = Nothing
  longest (m : ms) = Just (foldl pick m ms)
  pick best@(n, _, _) new@(n', _, _) = if n' > n then new else best

-- -----------------------------------------------------------------------------
-- Token type

data Token = T AlexPosn Tkn
  deriving Show

tokPosn (T p _) = p

data Tkn
 = SpecialT Char
 | CodeT String
 | ZeroT
 | IdT String
 | StringT String
 | BindT String
 | CharT Char
 | SMacT String
 | RMacT String  
 | SMacDefT String
 | RMacDefT String  
 | NumT Int	
 | WrapperT
 | EOFT
 deriving Show

-- -----------------------------------------------------------------------------
-- Token functions

special   (p,_,str) ln = return $ T p (SpecialT  (head str))
zero      (p,_,str) ln = return $ T p ZeroT
string    (p,_,str) ln = return $ T p (StringT (extract ln str))
bind      (p,_,str) ln = return $ T p (BindT (takeWhile isIdChar str))
escape    (p,_,str) ln = return $ T p (CharT (esc str))
decch     (p,_,str) ln = return $ T p (CharT (do_ech 10 ln (take (ln-1) (tail str))))
hexch     (p,_,str) ln = return $ T p (CharT (do_ech 16 ln (take (ln-2) (drop 2 str))))
octch     (p,_,str) ln = return $ T p (CharT (do_ech 8  ln (take (ln-2) (drop 2 str))))
char      (p,_,str) ln = return $ T p (CharT (head str))
smac      (p,_,str) ln = return $ T p (SMacT (mac ln str))
rmac      (p,_,str) ln = return $ T p (RMacT (mac ln str))
smacdef   (p,_,str) ln = return $ T p (SMacDefT (macdef ln str))
rmacdef   (p,_,str) ln = return $ T p (RMacDefT (macdef ln str))
startcode (p,_,str) ln = return $ T p (IdT (take ln str))
wrapper   (p,_,str) ln = return $ T p WrapperT

isIdChar c = isAlphaNum c || c `elem` "_'"

extract ln str = take (ln-2) (tail str)
		
do_ech radix ln str = chr (parseInt radix str)

mac ln (_ : str) = take (ln-1) str

macdef ln (_ : str) = takeWhile (not . isSpace) str

esc (_ : x : _)  =
 case x of
   'a' -> '\a'
   'b' -> '\b'
   'f' -> '\f'
   'n' -> '\n'
   'r' -> '\r'
   't' -> '\t'
   'v' -> '\v'
   c   ->  c

parseInt :: Int -> String -> Int
parseInt radix ds = foldl1 (\n d -> n * radix + d) (map digitToInt ds)

-- In brace-delimited code, we have to be careful to match braces
-- within the code, but ignore braces inside strings and character
-- literals.  We do an approximate job (doing it properly requires
-- implementing a large chunk of the Haskell lexical syntax).

code (p,_,inp) len = do
 inp <- getInput
 go inp 1 ""
 where
  go inp 0 cs = do
    setInput inp
    return (T p (CodeT (reverse (tail cs))))
  go inp n cs = do
    case alexGetChar inp of
	Nothing  -> err inp
	Just (c,inp)   -> 
	  case c of
		'{'  -> go inp (n+1) (c:cs) 
		'}'  -> go inp (n-1) (c:cs)
		'\'' -> go_char inp n (c:cs)
		'\"' -> go_str inp n (c:cs) '\"'
		c    -> go inp n (c:cs)

	-- try to catch occurrences of ' within an identifier
  go_char inp n (c1:c2:cs) | isAlphaNum c2 = go inp n (c1:c2:cs)
  go_char inp n cs = go_str inp n cs '\''

  go_str inp n cs end = do
    case alexGetChar inp of
	Nothing -> err inp
	Just (c,inp)
	  | c == end  -> go inp n (c:cs)
	  | otherwise -> 
		case c of
		   '\\' -> case alexGetChar inp of
			     Nothing -> err inp
			     Just (d,inp)  -> go_str inp n (d:c:cs) end
		   c -> go_str inp n (c:cs) end

  err inp = do setInput inp; lexError "lexical error in code fragment"
				  


lexError s = do
  (p,_,input) <- getInput
  failP (s ++ (if (not (null input))
		  then " at " ++ show (head input)
		  else " at end of file"))

lexer :: (Token -> P a) -> P a
lexer cont = lexToken >>= cont

lexToken :: P Token
lexToken = do
  inp@(p,_,_) <- getInput
  sc <- getStartCode
  case alexScan inp sc of
    AlexEOF -> return (T p EOFT)
    AlexError _ -> lexError "lexical error"
    AlexSkip inp1 len -> do
	setInput inp1
	lexToken
    AlexToken inp1 len t -> do
	setInput inp1
	t inp len

type Action = AlexInput -> Int -> P Token

skip :: Action
skip _ _ = lexToken

andBegin :: Action -> StartCode -> Action
andBegin act sc inp len = setStartCode sc >> act inp len
