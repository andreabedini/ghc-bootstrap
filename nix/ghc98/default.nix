# GHC 9.8.4 built by the chain's GHC 9.4.8 (nix/ghc94) with Hadrian, GHC's
# own build system since the make build system went away in 9.6. 9.8.4 asks
# for a 9.4 or later as the bootstrapping compiler; 9.6 is skipped.
#
# Hadrian is a Haskell program with 18 Hackage dependencies (shake and its
# friends). GHC ships hadrian/bootstrap/bootstrap.py to build it with a bare
# GHC and no cabal-install, from a "bootstrap plan": a JSON file naming each
# dependency's version, Hackage revision and sha256. 9.8.4's newest plan is
# for a 9.4.4 boot compiler (plan-bootstrap-9_4_4.json, copied here verbatim
# from the tarball); the plan also lists the boot compiler's own libraries
# with their exact versions and bootstrap.py checks them with ghc-pkg, so
# the derivation rewrites those versions to the ones the chain's 9.4.8
# actually has (base 4.17.2.1 instead of 4.17.0.0, ...) before handing the
# plan over. The dependency tarballs and revised .cabal files are fetched by
# Nix with the plan's hashes and packed as the sources tarball bootstrap.py
# takes with -s, so the build itself needs no network. This is how Guix
# builds 9.8 too (nixpkgs builds Hadrian with its own Haskell package set).
#
# Flavour: default (-O2 libraries and compiler) with the libraries and the
# compiler linked statically (no_dynamic_libs, no_dynamic_ghc), no profiled
# libraries, no split sections, no documentation. Hadrian's `install`
# target builds the binary distribution, configures it with --prefix and
# runs its `make install`.
#
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed GHC
# 9.8.4, bin/ghc.
{ lib
, stdenv
, fetchurl
, perl
, python3
, autoconf
, automake
, m4
, gmp
, ncurses
, ghc94
}:

let
  plan = builtins.fromJSON (builtins.readFile ./plan-bootstrap-9_4_4.json);
  hackageDeps = builtins.filter (d: d.source == "hackage") plan.dependencies;
  srcOf = d: fetchurl {
    url = "https://hackage.haskell.org/package/${d.package}-${d.version}/${d.package}-${d.version}.tar.gz";
    sha256 = d.src_sha256;
  };
  cabalOf = d: fetchurl {
    name = "${d.package}-${d.version}-r${toString d.revision}.cabal";
    url = "https://hackage.haskell.org/package/${d.package}-${d.version}/revision/${toString d.revision}.cabal";
    sha256 = d.cabal_sha256;
  };
  # bootstrap.py -s wants a flat gzipped tar: plan-bootstrap.json, each
  # <pkg>-<ver>.tar.gz and each <pkg>.cabal (it verifies the .cabal's hash
  # whatever the revision).
  stageSources = lib.concatMapStrings (d: ''
    cp ${srcOf d} bs/${d.package}-${d.version}.tar.gz
    cp ${cabalOf d} bs/${d.package}.cabal
  '') hackageDeps;
  flavour = "default+no_dynamic_libs+no_dynamic_ghc+no_profiled_libs+no_split_sections";
in
stdenv.mkDerivation {
  pname = "ghc";
  version = "9.8.4";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/9.8.4/ghc-9.8.4-src.tar.xz";
    sha256 = "17e8188f3c8a5c2f73fb4e35d01032e8dc258835ec876d52c8ad8ee3d24b2fc5";
  };
  nativeBuildInputs = [ perl python3 autoconf automake m4 ghc94 ghc94.happy120 ghc94.alex327 ];
  buildInputs = [ gmp ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc94.nonPie;
  passthru = {
    inherit (ghc94) nonPie;
    inherit plan;
    # nix-build -A ghc98.bootstrapSources fetches the 36 files ahead of the build
    bootstrapSources = map srcOf hackageDeps ++ map cabalOf hackageDeps;
  };

  # gcc 15 defaults to C23, where `extern void *realloc();` declares a
  # function of no arguments: utils/hp2ps/Utilities.c (K&R-era) fails to
  # compile. Upstream's fix (GitLab !13863 for #25662, in 9.10 and later;
  # the Fedora copy is the one nixpkgs applies to GHC < 9.10): include
  # stdlib.h instead.
  patches = [ ./hp2ps-C-gnu17.patch ];

  postPatch = "patchShebangs .";
  configurePhase = ''
    runHook preConfigure
    ./configure --prefix=$out GHC=${ghc94}/bin/ghc CC=gcc \
      --with-gmp-includes=${gmp.dev}/include --with-gmp-libraries=${gmp}/lib
    grep -q 'GHC=${ghc94}/bin/ghc' config.log
    runHook postConfigure
  '';
  preBuild = ''
    ulimit -s unlimited; ulimit -c unlimited   # cores reach the host's coredumpctl
    # The bootstrap plan, with the boot libraries' versions as 9.4.8 has them.
    mkdir bs
    ${stageSources}
    python3 - <<'PY'
    import json, subprocess
    p = json.load(open('${./plan-bootstrap-9_4_4.json}'))
    for b in p['builtin']:
        v = subprocess.run(['${ghc94}/bin/ghc-pkg', 'field', b['package'], 'version', '--simple-output'],
                           capture_output=True, text=True, check=True).stdout.split()[0]
        if v != b['version']:
            print(f"plan: {b['package']} {b['version']} -> {v}")
        b['version'] = v
    json.dump(p, open('bs/plan-bootstrap.json', 'w'), indent=1)
    PY
    tar -C bs -czf bootstrap-sources.tar.gz .
    # Hadrian itself, by the 9.4.8: hadrian/_build/bin/hadrian.
    (cd hadrian && python3 bootstrap/bootstrap.py -w ${ghc94}/bin/ghc -s ../bootstrap-sources.tar.gz --no-archive)
    test -x hadrian/_build/bin/hadrian
  '';
  buildPhase = ''
    runHook preBuild
    hadrian/_build/bin/hadrian -j$NIX_BUILD_CORES --flavour=${flavour} --docs=none binary-dist-dir
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    hadrian/_build/bin/hadrian -j$NIX_BUILD_CORES --flavour=${flavour} --docs=none --prefix=$out install
    runHook postInstall
  '';
  enableParallelBuilding = true;

  # nix/test/T3.hs, compiled by the installed compiler with no extra flags.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t; cp ${../test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${../test/T3.out} t/out.txt
    $out/bin/ghc-pkg field ghc-bignum library-dirs | grep -q '${gmp}/lib'
    $out/bin/ghc --numeric-version | grep -qx 9.8.4
  '';
}
