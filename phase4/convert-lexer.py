#!/usr/bin/env python3
"""Convert GHC 6.2.2's shipped parser/Lexer.hs (alex 2.0 `-g` output) into a
form MicroHs can compile.  Every edit is asserted against the pristine text so
the script fails loudly if run on anything else.

Usage: convert-lexer.py <pristine Lexer.hs> <output Lexer.hs>
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
lines = open(src, encoding="latin-1").read().split("\n")
assert len(lines) == 1353 and lines[-1] == "", len(lines)   # 1352 lines + final newline

def expect(lineno, prefix):
    l = lines[lineno - 1]
    assert l.startswith(prefix), (lineno, l[:80], prefix)
    return l

out = []
i = 1
def emit(s): out.append(s)

# ---- 1. header: drop the GHC.Exts / GlaExts import block (lines 37-41) ------
for n in range(1, 37):
    emit(lines[n - 1])
expect(37, "#if __GLASGOW_HASKELL__ >= 503")
expect(38, "import GHC.Exts")
expect(40, "import GlaExts")
expect(41, "#endif")
emit("-- mhs: GHC.Exts/GlaExts are not needed: the alex -g template at the end of")
emit("-- this file is rewritten over boxed Ints (see AlexAddr below).")

# ---- 2. the four AlexA# "..."# tables (lines 42-53) -------------------------
for n in (42, 45, 48, 51):
    emit(expect(n, "alex_"))                         # type signature, unchanged
    l = expect(n + 1, "alex_")
    name, _, rest = l.partition(" = ")
    assert rest.startswith('AlexA# "') and rest.endswith('"#'), (n + 1, rest[:20], rest[-5:])
    body = rest[len('AlexA# "'):-2]
    assert len(body) % 8 == 0 and body.count("\\x") == len(body) // 4, n + 1
    emit(f'{name} = alexA "{body}"')                 # mhs: same literal, decoded at runtime
    emit(expect(n + 2, ""))                          # blank
emit(expect(54, "alex_accept = listArray (0::Int,314)"))
emit(expect(55, '{-# LINE 297 "parser/Lexer.x" #-}'))

# ---- 3. the local unsafeAt (lines 56-59): mhs's Array exports one already ---
expect(56, "-- work around bug in Alex 2.0")
expect(57, "#if __GLASGOW_HASKELL__ < 503")
expect(58, "unsafeAt arr i = arr ! i")
expect(59, "#endif")
emit("-- mhs: the Alex-2.0 workaround `unsafeAt arr i = arr ! i` (for GHC < 503) is")
emit("-- dropped: MicroHs's Data.Array already exports unsafeAt, and a local")
emit("-- definition would make every use ambiguous.")

# ---- 4. user code, unchanged except the Monad P instance --------------------
# (and the `deriving Show` on Token__, which the shipped file keeps under
# #ifdef DEBUG: the token-dump driver switches it on with -DLEXER_SHOW_TOKENS
# so it need not enable DEBUG's ASSERTs in every module it pulls in)
for n in range(60, 874):
    if n == 204:
        expect(204, "#ifdef DEBUG")
        expect(205, "  deriving Show -- debugging")
        expect(206, "#endif")
        emit("-- mhs: LEXER_SHOW_TOKENS is defined only by the token-dump driver build")
        emit("#if defined(DEBUG) || defined(LEXER_SHOW_TOKENS)")
        continue
    emit(lines[n - 1])
expect(874, "instance Monad P where")
expect(875, "  return = returnP")
expect(876, "  (>>=) = thenP")
expect(877, "  fail = failP")
emit("-- mhs: Functor/Applicative are superclasses of Monad in modern base, and")
emit("-- fail lives in MonadFail (the lexer's do-blocks bind refutable patterns).")
emit("instance Functor P where")
emit("  fmap f m = m `thenP` \\ a -> returnP (f a)")
emit("instance Applicative P where")
emit("  pure = returnP")
emit("  mf <*> ma = mf `thenP` \\ f -> ma `thenP` \\ a -> returnP (f a)")
emit("instance Monad P where")
emit("  return = returnP")
emit("  (>>=) = thenP")
emit("instance MonadFail P where")
emit("  fail = failP")
for n in range(878, 1208):
    emit(lines[n - 1])

# ---- 5. the -g template runtime (lines 1208-1352), rewritten -----------------
expect(1208, "data AlexAddr = AlexA# Addr#")
expect(1211, "alexIndexShortOffAddr (AlexA# arr) off =")
expect(1235, "data AlexReturn a")
expect(1242, "alexScan input (I# (sc))")
expect(1276, "alex_scan_tkn user orig_input len input s last_acc =")
expect(1282, "alex_scan_tkn' user orig_input len input s last_acc =")
expect(1317, "data AlexLastAcc a")
expect(1343, "alexRightContext (I# (sc)) user _ _ input = ")
expect(1352, "iUnbox (I# (i)) = i")

emit(r'''-- mhs: The alex -g template stores each table as an Addr# byte string of
-- 16-bit little-endian entries and reads entry `off` with
--
--     alexIndexShortOffAddr (AlexA# arr) off = narrow16Int# i
--       where i    = word2Int# ((high `uncheckedShiftL#` 8#) `or#` low)
--             high = int2Word# (ord# (indexCharOffAddr# arr (off*2 + 1)))
--             low  = int2Word# (ord# (indexCharOffAddr# arr (off*2)))
--
-- (this alex 2.0 template has no WORDS_BIGENDIAN branch; the byte order is
-- fixed).  MicroHs has no Addr#, so the same string literals are decoded once
-- into a boxed Array Int Int.  The sign extension of narrow16Int# is
-- reproduced by hand: an entry >= 0x8000 is negative, so the "\xff\xff"
-- sentinels come out as -1, which is what alex_scan_tkn tests for.
newtype AlexAddr = AlexA (Array Int Int)

alexA :: String -> AlexAddr
alexA s = AlexA (listArray (0, n - 1) (decode s))
  where
    n = length s `div` 2
    decode (lo : hi : rest) = entry (ord lo + ord hi * 256) : decode rest
    decode _                = []
    entry v | v >= 32768 = v - 65536
            | otherwise  = v

alexIndexShortOffAddr :: AlexAddr -> Int -> Int
alexIndexShortOffAddr (AlexA arr) off = arr ! off

alexAddrSize :: AlexAddr -> Int
alexAddrSize (AlexA arr) = case bounds arr of (_, hi) -> hi + 1

alex_check_size :: Int
alex_check_size = alexAddrSize alex_check

-- -----------------------------------------------------------------------------
-- Main lexing routines

data AlexReturn a
  = AlexEOF
  | AlexError  !AlexInput
  | AlexSkip   !AlexInput !Int
  | AlexToken  !AlexInput !Int a

-- alexScan :: AlexInput -> StartCode -> Maybe (AlexInput,Int,act)
alexScan input sc
  = alexScanUser undefined input sc

alexScanUser user input sc
  = case alex_scan_tkn user input 0 input sc AlexNone of
	(AlexNone, input') ->
		case alexGetChar input of
			Nothing ->



				   AlexEOF
			Just _ ->



				   AlexError input

	(AlexLastSkip input len, _) ->



		AlexSkip input len

	(AlexLastAcc k input len, _) ->



		AlexToken input len k


-- Push the input through the DFA, remembering the most recent accepting
-- state it encountered.

-- mhs: s and len were Int#; `case s of -1# ->` becomes an Int comparison, and
-- len is forced with seq because a boxed accumulator would otherwise build a
-- thunk chain as long as the token.
alex_scan_tkn user orig_input len input s last_acc =
  input `seq` len `seq` -- strict in the input
  if s == -1
    then (last_acc, input)
    else alex_scan_tkn' user orig_input len input s last_acc

alex_scan_tkn' user orig_input len input s last_acc =
  let
	new_acc = check_accs (alex_accept `unsafeAt` s)
  in
  new_acc `seq`
  case alexGetChar input of
     Nothing -> (new_acc, input)
     Just (c, new_input) ->



	let
		base   = alexIndexShortOffAddr alex_base s
		ord_c  = ord c
		offset = (base + ord_c)
		check  = alexIndexShortOffAddr alex_check offset

		-- mhs: the `offset < alex_check_size` guard is new. With Addr#
		-- an out-of-range read of alex_check merely returned garbage
		-- (and could not match); a boxed array would raise instead.
		-- It only matters for a Char above the DFA's alphabet.
		new_s = if (offset >= 0) && (offset < alex_check_size) && (check == ord_c)
			  then alexIndexShortOffAddr alex_table offset
			  else alexIndexShortOffAddr alex_deflt s
	in
	alex_scan_tkn user orig_input (len + 1) new_input new_s new_acc

  where
	check_accs [] = last_acc
	check_accs (AlexAcc a : _) = AlexLastAcc a input len
	check_accs (AlexAccSkip : _)  = AlexLastSkip  input len
	check_accs (AlexAccPred a pred : rest)
	   | pred user orig_input len input
	   = AlexLastAcc a input len
	check_accs (AlexAccSkipPred pred : rest)
	   | pred user orig_input len input
	   = AlexLastSkip input len
	check_accs (_ : rest) = check_accs rest

data AlexLastAcc a
  = AlexNone
  | AlexLastAcc a !AlexInput !Int
  | AlexLastSkip  !AlexInput !Int

data AlexAcc a user
  = AlexAcc a
  | AlexAccSkip
  | AlexAccPred a (AlexAccPred user)
  | AlexAccSkipPred (AlexAccPred user)

type AlexAccPred user = user -> AlexInput -> Int -> AlexInput -> Bool

-- -----------------------------------------------------------------------------
-- Predicates on a rule

alexAndPred p1 p2 user in1 len in2
  = p1 user in1 len in2 && p2 user in1 len in2

--alexPrevCharIsPred :: Char -> AlexAccPred _
alexPrevCharIs c _ input _ _ = c == alexInputPrevChar input

--alexPrevCharIsOneOfPred :: Array Char Bool -> AlexAccPred _
alexPrevCharIsOneOf arr _ input _ _ = arr ! alexInputPrevChar input

--alexRightContext :: Int -> AlexAccPred _
alexRightContext sc user _ _ input =
     case alex_scan_tkn user input 0 input sc AlexNone of
	  (AlexNone, _) -> False
	  _ -> True
	-- TODO: there's no need to find the longest
	-- match when checking the right context, just
	-- the first match will do.

-- mhs: the template's `iUnbox (I# i) = i` ("used by wrappers") is dropped:
-- Lexer.x uses no wrapper, and FastTypes (imported whole) exports an iUnbox.
''')

open(dst, "w", encoding="latin-1").write("\n".join(out))
print(f"wrote {dst}: {len(out)} lines")
