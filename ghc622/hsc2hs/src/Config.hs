-- mhs: what ghc/utils/hsc2hs/Makefile's $(CONFIG_HS) rule writes from mk/config.mk
-- (DEFAULT_TMPDIR=/tmp, WhatGccIsCalled=gcc, exeext empty, unix pathSep).
module Config where
cDEFAULT_TMPDIR       = "/tmp"
cGCC                  = "gcc"
progNameSuffix        = ""
pathSep               = '/'
