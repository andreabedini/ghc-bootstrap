-- One definition of UArray, so that importing both Data.Array.IArray and
-- Data.Array.Unboxed does not make the name ambiguous (in real base both
-- re-export this module's definition). MicroHs has no unboxed arrays, so
-- UArray is a boxed Array with the same interface.
module Data.Array.Base(module Mhs.Array, UArray) where
import Mhs.Array

type UArray = Array
