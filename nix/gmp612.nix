# GMP 6.1.2 (2016), the last GMP before 6.2 made mpz_init lazy: a zero-valued
# result that an mpz function returns early (mpz_mul by zero, mpz_tdiv_q with
# |a| < |b|, ...) keeps _mp_d at GMP's static dummy_limb instead of memory the
# GHC runtime allocated in the Haskell heap. GHCs before 8.0 (6.2.2's J#,
# integer-gmp 0.x) take _mp_d - sizeof(StgArrWords) as the closure, and the
# garbage collector then evacuates a pointer into libgmp's data segment
# (nix/test/GmpZero.hs reproduces it; DECISIONS.md D52). Every rung before
# 8.0 links against this GMP; 8.0's integer-gmp works on limbs itself.
#
# Built as nixpkgs builds gmp, minus the fat-binary and C++ options the chain
# does not need.
{ stdenv
, fetchurl
, m4
}:

stdenv.mkDerivation {
  pname = "gmp";
  version = "6.1.2";
  src = fetchurl {
    url = "https://ftp.gnu.org/gnu/gmp/gmp-6.1.2.tar.xz";
    hash = "sha256-h7Vl6JqaaE/k6+7duDmdziWZ+ckEmFTKjA373qDiGRI=";
  };
  nativeBuildInputs = [ m4 ];
  hardeningDisable = [ "all" ];
  # gcc 15 defaults to C23, which rejects the K&R test programs of a 2016
  # configure ("could not find a working compiler"); GMP takes CFLAGS as
  # given. No -fno-pie/-no-pie here: a shared library is PIC, and -no-pie on
  # a -shared link makes gcc look for main().
  env.CFLAGS = "-O2 -std=gnu11";
  # the generic C implementation, not the per-CPU assembly: what the build
  # produces then does not depend on the build machine's CPU
  configureFlags = [ "--disable-assembly" "--with-pic" ];
  enableParallelBuilding = true;
  doCheck = true;
}
