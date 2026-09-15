module CastProbe(main) where
import Data.Double(castDoubleToWord64)
import Data.Float(castFloatToWord32)
main :: IO ()
main = print (castDoubleToWord64 1.0, castFloatToWord32 1.0)
