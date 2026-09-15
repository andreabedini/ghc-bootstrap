-- FastString, reimplemented over MicroHs's own facilities.
--
-- GHC 4.08's FastString is a packed byte array plus a hash-consed unique, built
-- with ByteArray#/Addr# primops and a hand-rolled hash table. None of that
-- machinery exists in MicroHs, and emulating GHC's array primops to get it
-- would be far more work -- and far less trustworthy -- than reimplementing the
-- ~20 functions it exports. This is the "shim implemented over MicroHs's lib"
-- that BOOTSTRAP-ANALYSIS.md's Phase 2 calls for.
--
-- Interning is kept, because it is semantically load-bearing rather than an
-- optimisation: Unique.getUnique is defined as uniqueOfFS, so two equal strings
-- must yield the same Int or the compiler's name resolution breaks.
module FastString(
  FastString(..),
  mkFastString, mkFastSubString, mkFastSubStringFO,
  mkFastCharString, mkFastCharString2,
  mkFastSubStringBA, mkFastSubString,
  uniqueOfFS, lengthFS, nullFastString,
  getByteArray, unpackFS, appendFS, headFS, tailFS,
  concatFS, consFS, indexFS, hPutFS,
  ) where

import Data.IORef
import System.IO(Handle, hPutStr)
import System.IO.Unsafe(unsafePerformIO)
import qualified Data.Map as M
import PrelArr(ByteArray(..))
import PrelAddr(Addr(..))

data FastString = FastString !Int String     -- unique, contents

instance Eq FastString where
  FastString u1 _ == FastString u2 _ = u1 == u2

instance Ord FastString where
  compare (FastString _ s1) (FastString _ s2) = compare s1 s2

instance Show FastString where
  show (FastString _ s) = s

-- The intern table. One IORef holding (next unique, String -> unique); the
-- table is only ever grown, and unsafePerformIO with NOINLINE is the standard
-- way to have exactly one of them.
{-# NOINLINE internTable #-}
internTable :: IORef (Int, M.Map String Int)
internTable = unsafePerformIO (newIORef (1, M.empty))

intern :: String -> Int
intern s = unsafePerformIO $ do
  -- mhs: force s to normal form *before* reading the table. Forcing s can
  -- itself call intern: OccName.mkWorkerOcc builds "$w" ++ occNameString occ,
  -- and occNameString forces occ's FastString, whose strict unique field is
  -- an intern thunk that may not have run yet. When M.lookup forced s *after*
  -- the snapshot was taken, the nested call's insert was overwritten by the
  -- outer one and both strings got the same unique. Seen as GHC.List.hi
  -- carrying two signatures named $w$smaximum ($smaximum had been evicted),
  -- so every importer that inlined the wrapper looped in the simplifier
  -- (Data.Complex, Data.Graph, System.Console.GetOpt). GHC's real
  -- mkFastString hashes the whole string before touching its table, so it
  -- never had this re-entrancy. The insert is forced too, so the IORef never
  -- holds a chain of unevaluated inserts.
  forceString s
  (next, tbl) <- readIORef internTable
  case M.lookup s tbl of
    Just u  -> return u
    Nothing -> do
      let tbl' = M.insert s next tbl
      tbl' `seq` writeIORef internTable (next + 1, tbl')
      return next

-- Evaluate the spine and every character (mhs).
forceString :: String -> IO ()
forceString s = foldr seq () s `seq` return ()

mkFastString :: String -> FastString
mkFastString s = FastString (intern s) s

mkFastSubString :: Addr -> Int -> Int -> FastString
mkFastSubString _ _ _ = mkFastString ""       -- only used by the C-string path

mkFastSubStringFO :: a -> Int -> Int -> FastString
mkFastSubStringFO _ _ _ = mkFastString ""

mkFastCharString :: Addr -> FastString
mkFastCharString _ = mkFastString ""

mkFastCharString2 :: Addr -> Int -> FastString
mkFastCharString2 _ _ = mkFastString ""

mkFastSubStringBA :: ByteArray Int -> Int -> Int -> FastString
mkFastSubStringBA (ByteArray _ _ s) start len =
  mkFastString (take len (drop start s))

uniqueOfFS :: FastString -> Int
uniqueOfFS (FastString u _) = u

lengthFS :: FastString -> Int
lengthFS (FastString _ s) = length s

nullFastString :: FastString -> Bool
nullFastString (FastString _ s) = null s

getByteArray :: FastString -> ByteArray Int
getByteArray (FastString _ s) = ByteArray 0 (length s - 1) s

unpackFS :: FastString -> String
unpackFS (FastString _ s) = s

appendFS :: FastString -> FastString -> FastString
appendFS a b = mkFastString (unpackFS a ++ unpackFS b)

headFS :: FastString -> Char
headFS (FastString _ s) = head s

tailFS :: FastString -> FastString
tailFS (FastString _ s) = mkFastString (tail s)

concatFS :: [FastString] -> FastString
concatFS = mkFastString . concatMap unpackFS

consFS :: Char -> FastString -> FastString
consFS c fs = mkFastString (c : unpackFS fs)

indexFS :: FastString -> Int -> Char
indexFS (FastString _ s) i = s !! i

hPutFS :: Handle -> FastString -> IO ()
hPutFS h (FastString _ s) = hPutStr h s
