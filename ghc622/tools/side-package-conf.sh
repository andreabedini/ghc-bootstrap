#!/bin/sh
# The side package.conf of the chain's 6.2.2 as an installed compiler
# (ghc622/nix/boot.nix): parsec, compiled into PREFIX/libraries/parsec, which
# genprimopcode needs, and the empty packages unix, lang, util, text and data,
# which 6.2.2's own utils and 6.6's build name. Written in the format
# 6.2.2's ghc-pkg writes, so ghc-pkg can read and extend it.
#   sh side-package-conf.sh PREFIX > PREFIX/package.conf
set -eu
P=${1:?usage: side-package-conf.sh PREFIX}
pkg() { # name import/library dir (may be empty) hs_library (may be empty)
  if [ -n "$2" ]; then d="[ \"$2\" ]"; else d="[  ]"; fi
  if [ -n "$3" ]; then l="[ \"$3\" ]"; else l="[  ]"; fi
  printf 'Package {\n'
  printf '        name           = "%s",\n' "$1"
  printf '        auto           = False,\n'
  printf '        import_dirs    = %s,\n' "$d"
  printf '        source_dirs    = [],\n'
  printf '        library_dirs   = %s,\n' "$d"
  printf '        hs_libraries   = %s,\n' "$l"
  printf '        extra_libraries = [],\n'
  printf '        include_dirs   = [],\n'
  printf '        c_includes     = [],\n'
  printf '        package_deps   = [ "base" ],\n'
  printf '        extra_ghc_opts = [],\n'
  printf '        extra_cc_opts  = [],\n'
  printf '        extra_ld_opts  = []\n'
  printf '}'
}
printf '[\n'
pkg unix "" "";                                printf ',\n'
pkg parsec "$P/libraries/parsec" HSparsec;      printf ',\n'
pkg lang "" "";                                printf ',\n'
pkg util "" "";                                printf ',\n'
pkg text "" "";                                printf ',\n'
pkg data "" "";                                printf '\n'
printf ']\n'
