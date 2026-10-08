# Overrides for ghc/compiler/Makefile's $(CONFIG_HS) rule, which writes
# main/Config.hs from mk/config.mk (tools/config-hs.sh reads this file after
# the Makefile). Two kinds of value are set here rather than taken from
# configure. Deliberate: an unregisterised build, booted (as far as Config
# knows) by 4.08.2 -- stage 2 substitutes 6.2.2 (nix/stage2.nix) -- and no
# in-place driver layout, since every stage runs with -B<topdir>. Probed on
# the host by configure, pinned so the file does not depend on the machine:
# gmp, perl, cp, the C compiler, cpp's flags, diff, the temporary directory.
GhcVersion          = 4.08.2
GhcUnregisterised   = YES
BLD_DLL             =
PROJECT_DIR         =
GHC_DRIVER_DIR_REL  =
GHC_TOUCHY_DIR_REL  =
GHC_UNLIT_DIR_REL   =
GHC_MANGLER_DIR_REL =
GHC_SPLIT_DIR_REL   =
GHC_SYSMAN          =
EnableWin32DLLs     = NO
HaveLibGmp          = YES
GHC_PERL            = perl
GHC_CP              = cp
WhatGccIsCalled     = gcc
RAWCPP_FLAGS        = -undef -traditional
CONTEXT_DIFF        = diff -U 1
DEFAULT_TMPDIR      = /tmp
