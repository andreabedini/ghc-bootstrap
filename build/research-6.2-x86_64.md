# Was GHC 6.2.2 ever a working x86-64 compiler? (web research, 2026-09-09)

**Answer: yes, in exactly one configuration: unregisterised via-C**
(`GhcUnregisterised=YES`, `SplitObjs=NO`, plain ANSI C through gcc, no mangler).
That configuration was self-hosting (Debian amd64 ghc6 "can build itself"),
passed the testsuite on amd64/OpenBSD, and was shipped by Debian, Ubuntu,
Gentoo and OpenBSD. It had no GHCi, no NCG, no `foreign import "wrapper"` /
`foreign export dynamic` (adjustors), and no object splitting.
Registerised 6.2.x on x86-64 never worked (gcc PR 7871 plus unfinished
mangler/RTS work); it first worked in HEAD on 2005-03-08, days before 6.4.
x86-64 NCG landed 2005-04; GHCi 2005-07; both released in 6.4.1.

The x86-64 code in the 6.2.2 tarball is Simon Marlow's initial commit of
2003-08-29 plus a small follow-up by Ian Lynagh: DriverFlags.hs, MachRegs.h,
TailCalls.h, rts/Linker.c, rts/StgCRun.c, plus the `SIZEOF_VOID_P == 8`
HEAP_ALLOCED hack in rts/MBlock.h. Commits: ghc/ghc 7dc9735, 5c0bddf, 6f0dcaf.
No ghc-6-2-branch commit between 6.2 and 6.2.2 mentions x86_64.

## Milestones

| Milestone | Release |
|---|---|
| Platform recognised, unregisterised works | 6.2 (Dec 2003) |
| First official x86_64 bindist | 6.4 (2005-03-11) |
| Registerised via-C | 6.4 (HEAD 2005-03-08) |
| NCG | 6.4.1 (HEAD 2005-04) |
| GHCi, adjustors, -split-objs | 6.4.1 |

Release notes, verbatim:
- 6.2: "Initial support for the x86-64 (or amd64) platform." and "a detailed set
  of instructions in the building guide for getting an unregisterised build of
  GHC up and running on a new architecture."
- 6.2.1/6.2.2: no separate notes; 6.2.2 announcement: "a bugfix release only".
  6.2.1 download page: "Only x86 and sparc are registerised."
- 6.2 and 6.4 building guide: "x86_64-unknown-linux: GHC currently works
  unregisterised. A registerised port is in progress."
- 6.4.1: "Much improved support for the amd64/Linux platform, including GHCi,
  Template Haskell, a native code generator, foreign import "wrapper", and
  -split-objs."

## Who built 6.2.x on x86-64

- Debian (Ian Lynagh), 2004-06-12: unregisterised ghc6 6.2.1-2 amd64;
  recipe: `echo GhcUnregisterised=YES > mk/build.mk; echo SplitObjs=NO >>
  mk/build.mk; ./configure; make`. ghc6 6.2.2-3 has amd64 binaries.
  Marlow 2005-03: "That build of ghc6 is what we call 'unregisterised' ... it
  generates plain ANSI C code, which gcc compiles fine".
- Ubuntu hoary ghc6 6.2.2-2 amd64 built.
- Gentoo bug 58588 (2004-07): ghc-6.2.1-r2 works on amd64, unregisterised,
  bootstrapped from Debian debs; GHCi non-functional (bug 82541: "HSbase.o:
  unknown architecture").
- OpenBSD (Don Stewart), June 2004: unregisterised 6.2.1 amd64 passes the
  whole testsuite; "as fast as my 2.4GHz P4 registerised".
- hc-file route: a 6.2.1 hc bundle built in 32-bit mode on the host, then
  `distrib/hc-build --enable-hc-boot-unregisterised` on the 64-bit side;
  failed with `multiple definition of forkOS_entry` (libraries/base/Makefile),
  patch by Marlow; unclear whether it reached 6.2.2.

## x86-64 bugs in 6.2.x fixed later

1. Registerised mode crashes (mangler/TailCalls, gcc register vars): HEAD
   Mar-Apr 2005 only.
2. rts/MBlock.h 64-bit HEAP_ALLOCED is a documented hack ("lower 32 bits of the
   address ... won't go wrong until we've allocated 4G"); real 64-bit mblock
   map 2004-11-10 (61ccfec, in 6.4). A 2004 symptom on unregisterised
   6.2.20040613: `internal error: getMBlock: mmap: Invalid argument` with
   garbage sizes at the third mblock request; root cause not recorded.
3. Adjustors: `barf("adjustor creation not supported on this platform")` on
   x86_64; implemented 2005-03-10, in 6.4.1.
4. GHCi: Linker.c defines ELF_64BIT for x86_64 but has no relocations;
   added 2005-07-11.
5. -split-objs unsupported until 2005.
6. "Fix some incorrect use of int/nat that breaks x86_64" (0e6d231,
   2005-04-29); `mulMayOflo()` wrong on 64-bit (a31c721, 2005-07-14);
   amd64 needs larger thread stacks in some tests.

## The 6.2-era hc-boot procedure

The building guide's "Porting GHC" chapter requires a working GHC of the same
version on a host H to produce the .hc files: configure on a GHC-less box
fails with "GHC is required unless bootstrapping from .hc files". Steps on T:
`./configure --enable-hc-boot --enable-hc-boot-unregisterised`, `make config.h`
in ghc/includes; on H: build with GhcUnregisterised=YES, TARGETPLATFORM set, T's
config.h copied in, then `make hc-file-bundle Project=Ghc`; on T:
`./distrib/hc-build --enable-hc-boot-unregisterised`. The .hc files are
platform-specific (word size, SIZEOF_mp_limb_t, Constants.hs bakes in the word
size). For the MicroHs route: MicroHs stands in for host H, and the compiler
proper it builds must be configured as an x86_64 target (8-byte words) so the
emitted .hc files match the 64-bit RTS.

## Not confirmed
- Whether the 6.4 x86_64 bindist was registerised (very likely).
- Whether the forkOS_entry hc-boot fix is in 6.2.2.
- Root cause of the 2004 getMBlock crash on unregisterised builds.
