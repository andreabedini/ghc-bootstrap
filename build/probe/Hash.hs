module Hash(main) where
import Unsafe.Coerce
foo# :: Int
foo# = 1
main :: IO ()
main = print (foo# + unsafeCoerce (2::Int))
