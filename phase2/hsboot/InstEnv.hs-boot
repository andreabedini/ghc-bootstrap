-- Hand-written. GHC's InstEnv.hi-boot declares `data InstEnv`, but the real
-- module defines it as a type synonym:
--
--     type InstEnv = [(TyVarSet, [Type], Id)]
--
-- GHC reconciles an abstract boot declaration with a synonym when it reads the
-- real interface; mhs does not, and the mismatch surfaces in Inst.lhs as
-- `InstEnv ~ [(UniqFM Var, [Type], Var)]`. hiboot2hsboot.py now emits the
-- synonym automatically, but it cannot know which modules the free names come
-- from, so this file supplies the imports.
module InstEnv where
import {-# SOURCE #-} TypeRep
import {-# SOURCE #-} Var
import VarSet(TyVarSet)

type InstEnv = [(TyVarSet, [TypeRep.Type], Var.Id)]
