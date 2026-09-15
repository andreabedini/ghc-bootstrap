module CgUsages where
import AbsCSyn
import {-# SOURCE #-} CgMonad

getSpRelOffset :: AbsCSyn.VirtualSpOffset -> CgMonad.FCode AbsCSyn.RegRelative
