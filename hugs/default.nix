# Hugs 98 (Sep 2006) with pattern guards (0002) and a bigger control stack
# (0003); hugs/build-hugs.sh explains the permissive CC.
{ stdenv, fetchurl, bison }:
stdenv.mkDerivation {
  pname = "hugs";
  version = "Sep2006";
  src = fetchurl {
    url = "https://www.haskell.org/hugs/downloads/2006-09/hugs98-plus-Sep2006.tar.gz";
    sha256 = "aafaca9ca544572ebef70bbe86b5eb0abaa5d7c11c0b766d7db72a46b022bed5";
  };
  patches = [
    ./patches/0002-hugs-pattern-guards.patch
    ./patches/0003-hugs-bigger-control-stack.patch
  ];
  patchFlags = [ "-p0" ];
  nativeBuildInputs = [ bison ];
  hardeningDisable = [ "all" ];
  # The permissive flags ride in CC and are exported for make as well as
  # configure (hugs/build-hugs.sh, fixes 1-3).
  preConfigure = ''
    sed -i 's|^tmpdir_root=/tmp$|tmpdir_root=$TMPDIR|' libraries/tools/make_bootlib
    sed -i 's|= /bin/cp$|= cp|' libraries/Makefile.in demos/Makefile.in
    export CC="gcc -std=gnu89 -fcommon -fpermissive -w" CFLAGS=-O1
  '';
  # configure turns stdenv's STRIP=strip into a bare `strip` line after the link.
  makeFlags = [ "STRIP=:" ];
}
