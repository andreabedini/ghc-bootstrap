# GHC 6.6 built by the chain's GHC 6.2.2 (build/ghc66-by-622, NOTES.md):
# unregisterised via C, no GHCi, no native code generator, no profiling, with
# the four tree edits of ghc-6.6-by-622.patch.
#
# None of the tarball's generated parsers and lexers is used. The seven files
# below are deleted after unpacking, and 6.6's own Makefile rules regenerate
# them: Parser.y from Parser.y.pp by `gcc -E -traditional -P`, the .y files by
# happy 1.16 -agc (nix/ghc66/happy116.nix), the .x files by alex 2.1.0 -g
# (nix/ghc66/alex210.nix), the versions that made the shipped files. After the build
# each regenerated file must equal the shipped one, modulo blank lines and LINE
# pragmas (nix/ghc66/cmp-generated.sh).
#
# The compiler is nix/ghc622/inst.nix. The 6.6 build runs configure, make,
# make install, and test/T2.hs through the installed compiler. Output: an
# installed GHC 6.6, bin/ghc.
#
# Non-PIE (nix-non-pie): every gcc call, including the ones both GHCs make
# for .hc files and links, goes through the cc wrapper, so -fno-pie/-no-pie
# are given there rather than in each Makefile.
{ stdenv
, fetchurl
, perl
, gmp
, readline
, ncurses
, happy116
, alex210
, ghc622
}:

let
  inst = ghc622;
  generated = [
    "compiler/parser/Parser.y"
    "compiler/parser/Parser.hs"
    "compiler/parser/ParserCore.hs"
    "compiler/parser/Lexer.hs"
    "compiler/cmm/CmmParse.hs"
    "compiler/cmm/CmmLex.hs"
    "compiler/main/ParsePkgConf.hs"
  ];
  files = builtins.concatStringsSep " " generated;
in
stdenv.mkDerivation {
  pname = "ghc";
  version = "6.6";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/6.6/ghc-6.6-src.tar.bz2";
    sha256 = "79b2a29136d56c8120a526188297603304dc80d3093cda76fde939df7d4dcc7e";
  };
  patches = [ ../../build/ghc66-by-622/ghc-6.6-by-622.patch ];
  patchFlags = [ "-p1" ];
  nativeBuildInputs = [ perl happy116 alex210 ];
  buildInputs = [ gmp readline ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = inst.nonPie;

  postPatch = ''
    patchShebangs .
    for f in ${files}; do mkdir -p $NIX_BUILD_TOP/shipped/$(dirname $f); mv $f $NIX_BUILD_TOP/shipped/$f; done
  '';
  # build-66.sh's configure line
  configurePhase = ''
    ./configure --prefix=$out --with-ghc=${inst}/bin/ghc --with-gcc=gcc \
      CFLAGS="-std=gnu89 -fpermissive -w"
    grep -q 'with-ghc=${inst}/bin/ghc' config.log
    grep -Eq '^HAPPY[[:space:]]*=[[:space:]]*${happy116}/bin/happy$' mk/config.mk
    grep -Eq '^ALEX[[:space:]]*=[[:space:]]*${alex210}/bin/alex$' mk/config.mk
  '';
  preBuild = "ulimit -s unlimited";
  postBuild = ''
    for f in ${files}; do sh ${./cmp-generated.sh} $f $NIX_BUILD_TOP/shipped/$f; done
  '';
  enableParallelBuilding = false;

  # test/T2.hs by the installed compiler, with no extra flags (NOTES.md,
  # "Verification"); the expected output is T2's by construction.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t2; cp ${../../build/ghc66-by-622/test/T2.hs} t2/T2.hs
    (cd t2 && $out/bin/ghc -v0 --make T2.hs -o t2 && ./t2 > out.txt)
    cat > t2/expected.txt <<'EOF'
    hello from ghc 6.6 built by 6.2.2
    ([1,2,3],[(1,"a"),(2,"b")])
    (1606938044258990275541962092341162602522202993782792835301376,-9223372036854775808,9223372036854775807)
    ("1.5",2.25,2)
    Left divide by zero
    2568
    EOF
    diff t2/expected.txt t2/out.txt
    $out/bin/ghc --numeric-version | grep -qx 6.6
  '';
}
