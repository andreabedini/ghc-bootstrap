-- Haskell 98's Directory (ghc622/shims-h98/Directory.hs re-exports MicroHs's
-- System.Directory), plus getModificationTime, which GHC 6.0's --make and
-- recompilation checks use and MicroHs's System.Directory does not provide
-- (it has no stat). Compiling the compiler never calls it; running --make
-- would need a stat primitive in MicroHs.
module Directory(module System.Directory, getModificationTime) where
import System.Directory
import Time(ClockTime)

getModificationTime :: FilePath -> IO ClockTime
getModificationTime _ = ioError (userError "getModificationTime: no stat in MicroHs")
