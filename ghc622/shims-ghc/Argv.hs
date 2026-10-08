-- GHC 4.08.2's Argv reads the RTS globals prog_argv/prog_argc through GHC 4's
-- C-label syntax (``prog_argv''), which is a GHC-only extension and the one
-- place in the compiler where it appears in code rather than in a comment.
-- The module's entire purpose is to hand back the command line, so this
-- shadows it with getArgs.
module Argv(argv) where

import FastString(FastString, mkFastString)
import System.Environment(getArgs)
import System.IO.Unsafe(unsafePerformIO)

argv :: [FastString]
argv = map mkFastString (unsafePerformIO getArgs)
