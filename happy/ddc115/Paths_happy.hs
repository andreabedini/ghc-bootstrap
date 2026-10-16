-- Stand-in for the module Cabal generates, for happy 1.15 as patched by
-- happy-1.15-mhs.patch: Main reads its templates from getDataDir/templates.
module Paths_happy(version, getDataDir) where
import Data.Version(Version, makeVersion)
import System.Environment(getEnv)

version :: Version
version = makeVersion [1,15]

getDataDir :: IO FilePath
getDataDir = getEnv "HAPPY_DATADIR"
