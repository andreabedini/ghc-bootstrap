-- Names GHC 4.08.2 expects from the Prelude that modern base has moved or
-- dropped. HsVersions.h imports this into every module that includes it, so
-- there is one place to record base drift rather than a patch per site.
--
-- The rule (DECISIONS.md D12): reproduce the *old* behaviour here rather than
-- adapt GHC's source to the new one, so the compiler's source keeps diffing
-- cleanly against the shipped tarball.
module GhcCompat(catch, fmapMaybe, genSym, castFloatToInt, castDoubleToInts, fixIO,
                 -- HsVersions.h's IBOX/CBOX expand to these, and the modules
                 -- that use them do not all import GlaExts themselves. GHC got
                 -- them from its Prelude; we get them from here, which
                 -- HsVersions.h imports everywhere.
                 pattern I#, pattern C#, pattern W#, pattern F#, pattern D#) where

import GlaExts(pattern I#, pattern C#, pattern W#, pattern F#, pattern D#)

import System.IO.Error(catchIOError)
import Data.Double(castDoubleToWord64)
import Data.Float(castFloatToWord32)
import Data.Bits((.&.), shiftR)
import Data.IORef
import System.IO.Unsafe(unsafePerformIO, unsafeInterleaveIO)

-- Haskell 98's Prelude.catch, removed when exceptions were generalised.
catch :: IO a -> (IOError -> IO a) -> IO a
catch = catchIOError

-- mhs resolves `fmap` at the wrong Functor instance in the compiler's four
-- FMAP sites -- it has instances for Maybe, [] and ((->) a), and commits before
-- the argument's type is known (the same limitation that stopped happy's GLR
-- backend, DECISIONS.md D13). All four sites are at Maybe, so HsVersions.h
-- points FMAP at this monomorphic version instead.
fmapMaybe :: (a -> b) -> Maybe a -> Maybe b
fmapMaybe = fmap

-- GHC 4.08 got fresh unique numbers from a C counter, genSymZh, reached with
-- _ccall_. Same counter, in Haskell. It is the hottest allocation in the
-- compiler ("one of the most hammered bits", says UniqSupply), so it stays a
-- plain IORef bump rather than anything cleverer.
{-# NOINLINE symCounter #-}
symCounter :: IORef Int
symCounter = unsafePerformIO (newIORef 0)

genSym :: IO Int
genSym = do
  n <- readIORef symCounter
  writeIORef symCounter (n + 1)
  return n

-- PprAbsC emits floating literals as the integers with the same bit pattern.
-- GHC did it by writing a Float into a mutable array and reading an Int back
-- out -- type punning through hslibs' MutableArray, which MicroHs has no
-- equivalent of. MicroHs does have the casts directly, which is both clearer
-- and less dependent on word sizes.
castFloatToInt :: Float -> Int
castFloatToInt f = fromIntegral (castFloatToWord32 f)

-- Two Ints when a Double takes two words, one when it takes one.
castDoubleToInts :: Bool -> Double -> [Int]
castDoubleToInts big d
  | big       = [ fromIntegral (w .&. 0xffffffff), fromIntegral (w `shiftR` 32) ]
  | otherwise = [ fromIntegral w ]
  where w = castDoubleToWord64 d

-- The value-recursion combinator for IO, used by TcMonad to tie the knot when
-- typechecking recursive groups.
--
-- The obvious `fixIO k = fix (\ ~m -> m >>= k)` typechecks and *diverges*:
-- running the action requires the action, which is its own fixpoint. The real
-- definition needs a cell plus lazy IO, so that `k` receives a thunk which is
-- only forced after `k` has produced the answer. Getting this wrong cost a
-- silent infinite loop that looked like a stack-size problem.
fixIO :: (a -> IO a) -> IO a
fixIO k = do
  ref <- newIORef (error "fixIO: the computation forced its own result")
  ans <- unsafeInterleaveIO (readIORef ref)
  r <- k ans
  writeIORef ref r
  return r
