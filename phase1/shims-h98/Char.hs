-- Haskell 98 spelled it isAlphanum; base later renamed it isAlphaNum.
module Char(module Data.Char, isAlphanum) where
import Data.Char

isAlphanum :: Char -> Bool
isAlphanum = isAlphaNum
