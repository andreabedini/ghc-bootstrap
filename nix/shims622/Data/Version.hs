-- Shim for GHC 6.2.2, whose base predates Data.Version (GHC 6.4): the part
-- happy 1.16 and alex 2.1.0 use (their Paths_* modules and --version).
module Data.Version (Version(..), showVersion) where

import List (intersperse)

data Version = Version { versionBranch :: [Int], versionTags :: [String] }
  deriving (Eq, Ord, Show)

showVersion :: Version -> String
showVersion (Version b t) =
  concat (intersperse "." (map show b)) ++ concatMap ('-' :) t
