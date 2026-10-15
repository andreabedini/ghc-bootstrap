# GMP 6.1.2

GMP 6.1.2 (2016). Every GHC before 8.0 in the chain links against it: 6.2.2,
6.6, 6.10.4, 6.12.3, 7.4.2 and 7.8.4.

```sh
nix-build -A gmp612
```

## Why not the host's GMP

This one cost a while to find. GMP 6.2 made `mpz_init` lazy. When an mpz
function returns a zero early (`mpz_mul` by zero, `mpz_tdiv_q` with
|a| < |b|, ...), the result's `_mp_d` keeps pointing at GMP's static
`dummy_limb` instead of memory the GHC runtime allocated in the Haskell heap.
GHCs before 8.0 (6.2.2's `J#`, integer-gmp 0.x) take
`_mp_d - sizeof(StgArrWords)` as the closure. The garbage collector then
evacuates a pointer into libgmp's data segment, and things crash much later
and far away. `common/test/GmpZero.hs` reproduces it ([D52](../DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)).

8.0's integer-gmp works on limbs itself, so from 8.0.2 on the chain uses the
host's GMP.

## Build

`default.nix` builds GMP the way nixpkgs does, minus the fat-binary and C++
options:
- `-std=gnu11`, because gcc 15's C23 default rejects the K&R test programs of
  the 2016 configure;
- the generic C implementation instead of per-CPU assembly, so the result does
  not depend on the build machine's CPU.
