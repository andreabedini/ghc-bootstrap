-- Haskell 98's Time, as far as GHC 6.0's compiler uses it: ClockTime for
-- linkable/source timestamps and getClockTime. MicroHs has no time library;
-- the clock comes from time(2) through the FFI.
module Time(ClockTime, getClockTime) where
import Foreign.Ptr(Ptr, nullPtr)
import Foreign.C.Types(CLong(..))

newtype ClockTime = TOD Integer deriving (Eq, Ord, Show)

foreign import ccall "time" c_time :: Ptr CLong -> IO CLong

getClockTime :: IO ClockTime
getClockTime = do
  t <- c_time nullPtr
  return (TOD (toInteger t))
