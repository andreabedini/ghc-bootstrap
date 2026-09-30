# The fixed-point check (build/Makefile compare3, compare4, compare5): the
# .hc each stage wrote, module by module, against the stage before.
#
#   stage 3 vs 2  reported: stage 2 was compiled by stage 1, whose shims give
#                 other FastString uniques, so names and emission order differ
#   stage 4 vs 3  reported: two native compilers from the same source; they
#                 differ in CoreUtils (one SRT pair swapped) and may in Pretty,
#                 whose Float literal has an uninitialised upper word
#                 (PprAbsC.floatToWord): 218/220 identical on Fedora, 219/220
#                 here, where that word came out 0 in stage 3 too (LOG.md)
#   stage 5 vs 4  must be identical in all 220: the build fails otherwise
#
# and the compiler binaries of stages 3 and 4 against each other (reported).
# Output: report.txt.
{ runCommand
, ghc622-stage2
, ghc622-stage3
, ghc622-stage4
, ghc622-stage5
}:

runCommand "ghc-6.2.2-fixpoint" { } ''
  s2=${ghc622-stage2.hc}/stage2 s3=${ghc622-stage3.hc}/stage3
  s4=${ghc622-stage4.hc}/stage4 s5=${ghc622-stage5}/stage5
  hcs=$(cd $s2 && find . -name '*.hc' | sort)
  test $(echo "$hcs" | wc -l) = 220
  # compare <newer> <older> <label>: prints the differing files and a summary;
  # sets $diff to the number that differ or are missing
  compare() {
    same=0; diff=0
    for f in $hcs; do
      if cmp -s $1/$f $2/$f; then same=$((same+1)); else diff=$((diff+1)); echo "differs: ''${f#./}"; fi
    done
    echo "$3 .hc: $same identical, $diff differ"
  }
  {
    compare $s3 $s2 "stage 3 vs stage 2"
    compare $s4 $s3 "stage 4 vs stage 3"
    compare $s5 $s4 "stage 5 vs stage 4"; fixdiff=$diff
    if cmp -s ${ghc622-stage3}/bin/ghc ${ghc622-stage4}/bin/ghc; then
      echo "stage 3 and stage 4 bin/ghc are byte-identical"
    else
      echo "stage 3 and stage 4 bin/ghc differ: $(cmp -l ${ghc622-stage3}/bin/ghc ${ghc622-stage4}/bin/ghc | wc -l) bytes"
    fi
  } > report.txt
  cat report.txt
  [ $fixdiff = 0 ] || { echo "no fixed point: stage 5 and stage 4 differ"; exit 1; }
  mkdir $out; cp report.txt $out/
''
