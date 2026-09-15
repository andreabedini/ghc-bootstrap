-- Minimal Text.PrettyPrint for ghc/utils/genapply/GenApply.hs under MicroHs.
-- MicroHs 0.16 ships no HughesPJ. GenApply uses text, int, char, empty,
-- vcat, nest, semi, comma, parens, brackets, render, <>, $$, <+>.
-- The output is C, so exact layout is irrelevant; a Doc is a list of lines.
module Text.PrettyPrint(Doc, text, int, char, empty, vcat, nest, semi, comma,
  parens, brackets, render, ($$), (<+>)) where
-- (<>) is the Prelude Semigroup operator under MicroHs, so Doc is a Semigroup.

newtype Doc = Doc [String]

infixr 6 <+>   -- same associativity as Prelude (<>), so they can be mixed
infixl 5 $$

text :: String -> Doc
text s = Doc [s]

int :: Int -> Doc
int = text . show

char :: Char -> Doc
char c = text [c]

empty :: Doc
empty = Doc []

semi, comma :: Doc
semi = char ';'
comma = char ','

parens, brackets :: Doc -> Doc
parens d = char '(' <> d <> char ')'
brackets d = char '[' <> d <> char ']'

nest :: Int -> Doc -> Doc
nest k (Doc ls) = Doc (map (replicate k ' ' ++) ls)

vcat :: [Doc] -> Doc
vcat = foldr ($$) empty

($$) :: Doc -> Doc -> Doc
Doc a $$ Doc b = Doc (a ++ b)

instance Semigroup Doc where
  Doc [] <> d = d
  d <> Doc [] = d
  Doc a <> Doc (b:bs) = Doc (init a ++ [last a ++ b] ++ map (replicate (length (last a)) ' ' ++) bs)

instance Monoid Doc where
  mempty = empty

(<+>) :: Doc -> Doc -> Doc
Doc [] <+> d = d
d <+> Doc [] = d
a <+> b = a <> text " " <> b

render :: Doc -> String
render (Doc ls) = unlines ls
