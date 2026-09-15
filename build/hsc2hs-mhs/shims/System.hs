-- mhs: Haskell 98's System for hsc2hs.  phase1/shims-h98/System.hs re-exports
-- System.Environment and System.Exit only; H98's System also has
-- system :: String -> IO ExitCode, which MicroHs keeps in System.Process.
module System(module System.Environment, module System.Exit, system) where
import System.Environment
import System.Exit
import System.Process (system)
