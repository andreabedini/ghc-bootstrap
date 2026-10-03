# A GHC built with Hadrian, GHC's own build system since the make build
# system went away in 9.6, by the chain's previous rung. Used by nix/ghc98,
# nix/ghc912 and nix/ghc914; the first of them says why each step is there.
#
# Hadrian is a Haskell program with Hackage dependencies (shake and its
# friends). GHC ships hadrian/bootstrap/bootstrap.py to build it with a bare
# GHC and no cabal-install, from a "bootstrap plan": a JSON file naming each
# dependency's version, Hackage revision and sha256 (`plan`). The plan also
# lists the boot compiler's own libraries with exact versions and
# bootstrap.py checks them with `ghc-pkg describe`, so the plan's versions
# are rewritten to the ones the boot compiler actually has before use. The
# dependency tarballs and revised .cabal files are fetched by Nix with the
# plan's hashes and packed as the sources tarball bootstrap.py takes with
# -s, so the build itself needs no network. This is how Guix builds 9.8 too
# (nixpkgs builds Hadrian with its own Haskell package set).
#
# Flavour: default (-O2 libraries and compiler) with the libraries and the
# compiler linked statically (no_dynamic_libs, no_dynamic_ghc), no profiled
# libraries, no split sections, no documentation. Hadrian's `install`
# target builds the binary distribution, configures it with --prefix and
# runs its `make install`. --with-gmp-* so the bignum package records the
# GMP directory (see nix/ghc94/ghc.nix): ghc-bignum up to 9.12, ghc-internal
# from 9.14, where the GMP backend lives (`gmpPackage`).
#
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed GHC,
# bin/ghc.
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
}:
{ version
, sha256               # of ghc-<version>-src.tar.xz
, bootGhc              # the chain's previous rung
, happy, alex          # build-tool-depends of compiler, genprimopcode, hpc
, plan                 # path of the plan-bootstrap-*.json
, patches ? [ ]
, gmpPackage ? "ghc-bignum"   # the package whose registration records GMP's directory: ghc-internal from 9.14
, notes ? ""           # for the derivation's passthru, free text
}:

let
  planJson = builtins.fromJSON (builtins.readFile plan);
  hackageDeps = builtins.filter (d: d.source == "hackage") planJson.dependencies;
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
  inherit version;
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/${version}/ghc-${version}-src.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [ perl python3 autoconf automake m4 bootGhc happy alex ];
  buildInputs = [ gmp ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = bootGhc.nonPie;
  passthru = {
    inherit (bootGhc) nonPie;
    plan = planJson;
    inherit notes;
    # nix-build -A ghcNN.bootstrapSources fetches the plan's files ahead of the build
    bootstrapSources = map srcOf hackageDeps ++ map cabalOf hackageDeps;
  };

  inherit patches;
  postPatch = "patchShebangs .";
  configurePhase = ''
    runHook preConfigure
    ./configure --prefix=$out GHC=${bootGhc}/bin/ghc CC=gcc \
      --with-gmp-includes=${gmp.dev}/include --with-gmp-libraries=${gmp}/lib
    grep -q 'GHC=${bootGhc}/bin/ghc' config.log
    runHook postConfigure
  '';
  preBuild = ''
    ulimit -s unlimited; ulimit -c unlimited   # cores reach the host's coredumpctl
    # The bootstrap plan, with the boot libraries' versions as ${bootGhc.version} has them.
    mkdir bs
    ${stageSources}
    python3 - <<'PY'
    import json, subprocess
    p = json.load(open('${plan}'))
    for b in p['builtin']:
        v = subprocess.run(['${bootGhc}/bin/ghc-pkg', 'field', b['package'], 'version', '--simple-output'],
                           capture_output=True, text=True, check=True).stdout.split()[0]
        if v != b['version']:
            print(f"plan: {b['package']} {b['version']} -> {v}")
        b['version'] = v
    json.dump(p, open('bs/plan-bootstrap.json', 'w'), indent=1)
    PY
    tar -C bs -czf bootstrap-sources.tar.gz .
    # Hadrian itself, by the ${bootGhc.version}: hadrian/_build/bin/hadrian.
    (cd hadrian && python3 bootstrap/bootstrap.py -w ${bootGhc}/bin/ghc -s ../bootstrap-sources.tar.gz --no-archive)
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
    mkdir t; cp ${./test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${./test/T3.out} t/out.txt
    $out/bin/ghc-pkg field ${gmpPackage} library-dirs | grep -q '${gmp}/lib'
    $out/bin/ghc --numeric-version | grep -qx ${version}
  '';
}
