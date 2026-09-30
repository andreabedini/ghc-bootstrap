# The HTYPE_* defines configure's K&R probes no longer produce under
# gcc >= 14 (DECISIONS.md D47). Output: the block to append to config.h.
{ runCommandCC }:
runCommandCC "ghc-6.2.2-htypes.h" { } ''
  gcc -O -w -o gen-htypes ${../../phase4/gen-htypes.c}
  ./gen-htypes > $out
''
