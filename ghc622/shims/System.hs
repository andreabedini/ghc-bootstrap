-- Haskell 98's System: what later split into System.Environment, System.Exit
-- and (for `system`) System.Cmd. GHC 6.0's SysTools shells out through it.
module System(module System.Environment, module System.Exit, system) where
import System.Environment
import System.Exit
import System.Cmd(system)
