-- Stand-in for happy's GLR backend.
--
-- happy's LALR path is all the bootstrap needs: GHC 4.08.2's Parser.y and
-- ParseIface.y are ordinary LALR grammars, and `--glr` is never used. The real
-- ProduceGLRCode.lhs does not compile under mhs (see notes/phase2/FINDINGS.md,
-- "open questions": mhs resolves an `fmap` at the function functor rather than
-- at Maybe), and rather than patch happy's source for a feature we do not use,
-- this module shadows it on the include path.
--
-- Same interface, same types; the one entry point refuses at run time. A
-- happy built this way is correct for every grammar that does not pass --glr,
-- and says so loudly for one that does.
module ProduceGLRCode
  ( produceGLRParser
  , DecodeOption(..)
  , FilterOption(..)
  , GhcExts(..)
  , Options
  ) where

import Grammar (Grammar)
import Target ()

data DecodeOption = TreeDecode | LabelDecode
data FilterOption = NoFiltering | UseFiltering
data GhcExts      = NoGhcExts | UseGhcExts String String

type DebugMode = Bool
type Options   = (DecodeOption, FilterOption, GhcExts)

produceGLRParser
  :: FilePath                   -- output file name
  -> String                     -- templates directory
  -> a                          -- ActionTable
  -> b                          -- GotoTable
  -> Maybe String               -- module header
  -> Maybe String               -- user-defined stuff
  -> (DebugMode, Options)
  -> Grammar
  -> IO ()
produceGLRParser _ _ _ _ _ _ _ _ =
  ioError (userError
    "this happy was built without GLR support (happy/noglr)")
