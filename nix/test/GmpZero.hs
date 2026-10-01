-- GMP >= 6.2 leaves a zero-valued mpz result's _mp_d at a static dummy limb
-- when the operation returns early without allocating (mpz_mul by zero,
-- mpz_tdiv_q with |a| < |b|, and others); pre-8.0 GHCs turn that into a J#
-- whose ByteArray# lies inside libgmp, and the next GC that evacuates it
-- dies. Many such zeros, made in several ways, kept live across collections.
-- Expected output: (2400000,0)
import Data.Bits
main :: IO ()
main = do
  let big i = fromIntegral (i :: Int) * (2 ^ (70 :: Int)) :: Integer
      is = [1 .. 300000 :: Int]
      zs = [ big i * 0 | i <- is ]
        ++ [ fromIntegral i `quot` big i | i <- is ]
        ++ [ fromIntegral i `div` big i | i <- is ]
        ++ [ big i `rem` big i | i <- is ]
        ++ [ big i `mod` big i | i <- is ]
        ++ [ big i .&. 0 | i <- is ]
        ++ [ big i `xor` big i | i <- is ]
        ++ [ big i `shiftR` 200 | i <- is ]
  print (length zs, sum zs)
