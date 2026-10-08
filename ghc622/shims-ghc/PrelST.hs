module PrelST(module Control.Monad.ST, StateAndPtr#) where
import Control.Monad.ST
data StateAndPtr# s a = StateAndPtr# s a
