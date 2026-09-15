-- Haskell 98's IO module: System.IO plus the IOError operations that later
-- moved to System.IO.Error.
module IO(module System.IO, module System.IO.Error) where
import System.IO
import System.IO.Error
