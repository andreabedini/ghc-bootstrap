-- Token dump driver for the mhs-compiled GHC 6.2.2 Lexer.
--
-- Runs Lexer.lexer over a file (or a built-in sample) through the P monad
-- exactly as Parser.y would, and prints one token per line with its span.
-- Its only purpose is to show that the decoded alex tables drive the DFA
-- correctly; it is not part of the compiler.
module Main(main) where

import Lexer
import StringBuffer      ( hGetStringBuffer, stringToStringBuffer )
import CmdLineOpts       ( defaultDynFlags, dopt_set, DynFlag(..) )
import SrcLoc            ( SrcLoc, mkSrcLoc, srcLocLine, srcLocCol )
import FastString        ( mkFastString )
import System.Environment( getArgs )

main :: IO ()
main = do
  args <- getArgs
  (buf, name) <- case args of
        (f:_) -> do b <- hGetStringBuffer f; return (b, f)
        []    -> do b <- stringToStringBuffer sample; return (b, "<sample>")
  let flags = dopt_set (dopt_set defaultDynFlags Opt_GlasgowExts) Opt_FFI
      loc   = mkSrcLoc (mkFastString name) 1 0      -- as HscMain does
  go (mkPState buf loc flags)
 where
  go st = case unP (lexer return) st of
    PFailed l1 l2 msg -> putStrLn ("FAILED " ++ span l1 l2 ++ ": " ++ showPFailed l1 l2 msg)
    POk st' (T l1 l2 t) -> do
        putStrLn (span l1 l2 ++ "\t" ++ show t)
        case t of
          ITeof -> return ()
          _     -> go st'

  span :: SrcLoc -> SrcLoc -> String
  span l1 l2 = show (srcLocLine l1) ++ ":" ++ show (srcLocCol l1)
               ++ "-" ++ show (srcLocLine l2) ++ ":" ++ show (srcLocCol l2)

sample :: String
sample = unlines
  [ "{-# OPTIONS -fglasgow-exts #-}"
  , "module Foo (bar, M.baz) where"
  , ""
  , "import qualified Data.Map as M"
  , ""
  , "-- a line comment, {- not nested"
  , "{- a block {- nested -} comment -}"
  , "bar :: Int -> Maybe [Char]"
  , "bar x | x > 0x1F = Just \"esc\\n\\\"q\\\"\\SOH\""
  , "      | otherwise = let y = 0o17 + 3.25e-2 * fromIntegral x' in Nothing"
  , "  where x' = x `div` 2"
  , "{-# INLINE bar #-}"
  , "baz = M.lookup 'c' m >>= \\(a, b) -> return (a +# b, a ==# 1#, 2.0##)"
  , "data T = T { f :: !Int } deriving (Eq)"
  , "foreign import ccall unsafe \"sin\" c_sin :: Double -> Double"
  , "class C a where { op :: a -> a ; op = id }"
  ]
