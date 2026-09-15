-- GHC 4.08's DirUtils reimplements getDirectoryContents with raw opendir(3)
-- calls through GHC 4's _ccall_ syntax, working around a bug in the
-- Directory.getDirectoryContents that shipped with the compilers of the day.
-- The bug is long gone and the _ccall_ syntax is unavailable, so this forwards
-- to the standard one -- which is what the module is trying to be.
module DirUtils(getDirectoryContents) where
import System.Directory(getDirectoryContents)
