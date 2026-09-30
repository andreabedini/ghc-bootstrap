# prelude/primops.txt and the ten tables ghc/compiler/Makefile makes from it.
# cpphs, not gcc's cpp: only cpphs --noline --strip reproduces the file
# (phase4/regen-generated.sh). It reads config.h through MachDeps.h, hence
# the configured tree.
{ runCommand, cpphs, ghc622-genprimopcode, ghc622-configured }:
runCommand "ghc-6.2.2-primops"
  { nativeBuildInputs = [ cpphs ghc622-genprimopcode ]; }
  ''
    T=${ghc622-configured}/ghc
    mkdir $out
    cpphs --noline --strip -I$T/includes $T/compiler/prelude/primops.txt.pp > $out/primops.txt
    for pair in data-decl:data-decl primop-tag:tag primop-list:list \
                has-side-effects:has-side-effects out-of-line:out-of-line \
                commutable:commutable needs-wrapper:needs-wrapper can-fail:can-fail \
                strictness:strictness primop-primop-info:primop-info; do
      genprimopcode --''${pair%%:*} < $out/primops.txt > $out/primop-''${pair##*:}.hs-incl
    done
  ''
