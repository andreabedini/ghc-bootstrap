-- Stand-in for the module Cabal generates. happy uses exactly two names.
module Paths_happy(version, getDataDir) where
import Data.Version(Version, makeVersion)
import System.Environment(getEnv)

version :: Version
version = makeVersion [1,19,5]

getDataDir :: IO FilePath
getDataDir = getEnv "HAPPY_DATADIR"
