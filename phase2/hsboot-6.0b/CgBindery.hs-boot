module CgBindery where
import VarEnv

type CgBindings = VarEnv.IdEnv CgIdInfo
data CgIdInfo
data VolatileLoc
data StableLoc

nukeVolatileBinds :: CgBindings -> CgBindings
