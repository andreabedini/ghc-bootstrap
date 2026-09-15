#!/bin/sh
# One iteration of the mhs-on-hugs build; prints just the error.
cd /home/andrea/work/haskell/ghc-bootstrap/MicroHs || exit 1
PATH=/home/andrea/work/haskell/ghc-bootstrap/phase0/prefix/bin:$PATH
export PATH
rm -f generated/hmhs.c
timeout "${TIMEOUT:-1800}" make generated/hmhs.c 2>&1 | grep -v '^runhugs .+P' | tail -12
