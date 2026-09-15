# GHC 6.2.2 RTS, unregisterised x86-64, gcc 16 (Fedora 44) — findings

*2026-09-09. Exploratory; about an hour wall clock.*

Tree: `build/rts622/ghc-6.2.2` (full extraction of `ghc-6.2.2-src.tar.bz2`).
Scripts: `build-rts.sh` (compile + archive), `apply-fixes.pl` (source
rewrites), `genapply/build-genapply.sh` (the one generated source), patches in
`patches/`. Everything below reproduces from a clean extraction by running
`apply-fixes.pl` (or applying the two patches) and then `build-rts.sh`.

## 1. configure

```
./configure --enable-hc-boot --enable-hc-boot-unregisterised \
            --host=x86_64-unknown-linux --build=x86_64-unknown-linux \
            --target=x86_64-unknown-linux
```

Exit 0 with **no patches, no cache seeding, no CFLAGS override**. The four
accommodations 4.08.2 needed (D31) are all gone in 6.2.2:

| 4.08.2 problem (D31)                       | 6.2.2                                                        |
|--------------------------------------------|--------------------------------------------------------------|
| `config.sub` rejects x86_64                | knows it (`config.sub:282,341,377`)                          |
| configure platform whitelist lacks x86_64  | native case `x86_64-*-linux*` (`configure:1628`)             |
| pre-C99 `main(){}` probes all fail         | autoconf 2.5x probes; only two fail (below), neither matters |
| happy version compared as a string         | not reached in hc-boot mode                                  |
| GMP probe links `mpz_fdiv_qr` (a macro)    | probes `__gmpz_fdiv_qr` directly -> `HaveLibGmp = YES`       |

Without a `ghc` on PATH configure normally dies at line 2104 ("GHC is required
unless bootstrapping from .hc files"); `--enable-hc-boot` is the switch that
lifts it, and `--enable-hc-boot-unregisterised` is what makes
`mk/bootstrap.mk:63-64` add `-DNO_REGS -DUSE_MINIINTERPRETER` to every C
compile. Resulting `mk/config.mk`: `HostArch_CPP = x86_64`, `BootingFromHc =
YES`, `BootingFromUnregisterisedHc = YES`, `HaveLibGmp = YES`,
`LeadingUnderscore = NO`. `mk/config.h`: `SIZEOF_VOID_P 8`, `SIZEOF_LONG 8`,
`SIZEOF_INT 4`, `SIZEOF_DOUBLE 8`, `WORDS_BIGENDIAN` undefined.

Two probes fail for the 2026-toolchain reason (their probe programs use
implicit declarations, a hard error since gcc 14): "working fork" (leaves
`HAVE_WORKING_FORK` undefined; nothing in `ghc/rts` reads it, `base` cbits use
`HAVE_VFORK`) and "ld understands -x" (`LdXFlag`, used only when installing
libraries). Left as is.

`ghc/includes/config.h` is not written by configure; `ghc/includes/Makefile`'s
`$(H_CONFIG)` rule prepends the platform defines to `mk/config.h`. Transcribed
by hand (as `phase2/mkconfig.sh` did): 283 defines, including
`#define x86_64_TARGET_ARCH 1`. `ghc/includes/gmp.h` is copied from
`ghc/rts/gmp/gmp.h` exactly as that Makefile does (the bundled GMP 4-era
header; the link uses the system `libgmp`, and the `__mpz_struct` layout is
the same).

## 2. Compile commands

Flags come from `ghc/rts/Makefile` `STANDARD_OPTS` (`-I../includes -I.
-Iparallel -DCOMPILING_RTS`), `mk/bootstrap.mk:63-64` (`-DNO_REGS
-DUSE_MINIINTERPRETER`), the driver (`DriverPipeline.hs:726`
`-D__GLASGOW_HASKELL__=622`, `-O`) and, for the `.hc` files, the driver's
`-x c` (`DriverPipeline.hs:710`). `-std=gnu89 -O` for the D41 reason:
`ghc/rts/Stable.h` still defines `deRefStablePtr` and friends `extern inline`.
Not carried over: `WARNING_OPTS` (warnings only), `GhcRtsCcOpts =
-fomit-frame-pointer`, `-ffloat-store`.

Plain C (`ghc/rts/*.c`, `hooks/*.c`, `parallel/*.c`):

```
gcc -c -std=gnu89 -O -w -fmax-errors=100 \
    -DNO_REGS -DUSE_MINIINTERPRETER -DCOMPILING_RTS -D__GLASGOW_HASKELL__=622 \
    -I$G/ghc/includes -I$G/ghc/rts -I$G/ghc/rts/parallel  X.c -o obj/X.o
```

Hand-written Abstract C (`ghc/rts/*.hc`, `parallel/FetchMe.hc`, generated
`AutoApply.hc`): the same, plus `-x c -include $G/ghc/includes/Stg.h`.

Excluded per the Makefile: `RtsDllMain.c` (DLL only), `parallel/SysMan.c`
(a separate program), `Vis*.c` (GTK front panel, off by default).

## 3. Object count

| class                         | files | first sweep     | after patches |
|-------------------------------|------:|-----------------|--------------:|
| `ghc/rts/*.c`                 |    44 | 37 ok, 7 failed |         44/44 |
| `ghc/rts/hooks/*.c`           |    11 | 11 ok           |         11/11 |
| `ghc/rts/parallel/*.c`        |    13 | 13 ok (all `#ifdef PAR`/`GRAN`, compile to nothing) | 13/13 |
| `.hc` shipped (8 + FetchMe)   |     9 | 8 ok, 1 failed  |           9/9 |
| `AutoApply.hc` (generated)    |     1 | not in tarball  |           1/1 |
| **total**                     |**78** | 69/77           |     **78/78** |

The first sweep produced 59 errors in 8 files (`gcc -fmax-errors=100`, all
enumerated in one pass): GC.c 44, Interpreter.c 4, Stable.c 3, BlockAlloc.c 2,
Linker.c 2, PrimOps.hc 2, GCCompact.c 1, Schedule.c 1.

## 4. Classification of every failure

**(a) 2026-toolchain C issues: 59 of 59.**

- 58 x cast-as-lvalue (`(StgClosure *)tmp = evacuate(...)`), the same GNU
  extension gcc dropped in 4.0 that D30/D40 hit 32 times in 4.08.2. Shapes:
  48 plain assignments, 5 compound assignments (`(W_)p += MBLOCK_SIZE`,
  `(StgPtr)frame += ...`, `(StgWord)q -= 1`), 1 post-increment
  (`((StgPtr)p)++`, PrimOps.hc:264), 4 address-of-cast
  (`& BCO_LIT(discr)` = `&(W_)literals[discr]`, Interpreter.c:1064-1103).
- 1 x `static StgClosure* static_objects;` (GC.c:84) against `extern
  StgClosure *static_objects;` in `StoragePriv.h:29`. A constraint violation
  that gcc 3.x let through; modern gcc rejects it.

No implicit declarations, no old-header problems: 6.2.2's C is five years
newer than 4.08.2's and it shows.

**(b) genuine x86-64 problems: none found at compile or link time.** Unlike
4.08.2, 6.2.2 knows the platform: `MachRegs.h:244-261` has an x86_64 register
map, `StgCRun.c:177` an assembler `StgRun`, `TailCalls.h:66` an x86_64 `JMP_`,
`Linker.c:2198` an x86_64 case. Under `USE_MINIINTERPRETER` none of the
arch-specific code is selected (the mini-interpreter `StgRun` is a C loop,
`JMP_` is `return`), so those paths were not exercised here. The 64-bit bugs
of D42 (`Words-1` underflow in `Updates.hc`, info-table jump) are runtime
properties of compiled Haskell and cannot be observed without a compiler
producing 6.2.2 `.hc` files; nothing in a C-only run contradicts or confirms
them.

**(c) missing platform support: Adjustor.c needs no stub.** 6.2.2's
`createAdjustor` ends in `#else barf("adjustor creation not supported on this
platform")` (Adjustor.c:485) and `freeHaskellFunctionPtr` in `#else
ASSERT(0)` (line 549); both compile and link on x86_64 as they are. The
`phase3/rts-x86_64-stubs.c` file is not needed. (`foreign export dynamic` is
still absent on x86_64 in 6.2.2, but it is absent honestly.)

**Not a C error but a build-system gap: `AutoApply.hc`.** `ghc/rts/Makefile`
generates it with `$(GHC_GENAPPLY)` — `ghc/utils/genapply/GenApply.hs`, a
599-line Haskell program — and the tarball does not ship it; `StgFun.h:20`
documents that the `stg_ap_*` entry code lives there. Without it the link has
21 undefined symbols (`stg_ap_{v,n,p,pp,...,ppppppp,f,d,l}_info`, the `_ret`
labels, `stg_arg_bitmaps`). Built it with the project's MicroHs
(`MicroHs/bin/mhs`, 0.16.6.0): needed `cpphs` on PATH, a writable `TMPDIR`,
`-D__GLASGOW_HASKELL__=622` to select the `Text.PrettyPrint`/`Data.*`
imports, `-DNO_REGS` as its Makefile passes when unregisterised, and a 50-line
`Text.PrettyPrint` shim (`genapply/shim/`) because MicroHs ships no HughesPJ.
Two mhs quirks worth remembering: `<>` is the Prelude `Semigroup` operator, so
the shim must give `Doc` a `Semigroup` instance rather than export its own
`<>`; and `<+>` must be `infixr 6` to mix with it. `genapply` emits 2209 lines;
they compile with the `.hc` command above.

## 5. Patches (`patches/`)

- `0001-rts-cast-as-lvalue.patch` — the 58 cast-as-lvalue sites in 8 files,
  rewritten mechanically by `apply-fixes.pl` from gcc's own error list:
  `(T)lv OP v` -> `*(T*)&(lv) OP v`, `((T)p)++` -> `(*(T*)&(p))++`,
  `&BCO_LIT(n)` -> `(W_ *)&literals[n]`. Meaning-preserving (D40), no
  knowledge of the left-hand types needed, and nothing outside the reported
  lines is touched.
- `0002-gc-static-objects-linkage.patch` — GC.c:84 drop `static`, matching
  the `extern` declaration the header already exports.

Verified: extracting `ghc/rts` fresh from the tarball and applying both
patches gives a tree identical (`diff -r`) to the working tree.

## 6. Link and run

`libHSrts.a`: 78 objects, 596 defined global symbols. Linked against
`-lgmp -lm -ldl`. Besides the AutoApply set, the RTS references 25 symbols
from compiled `base` (`GHCziBase_Izh_con_info`, `GHCziIOBase_stackOverflow_closure`,
`GHCziWeak_runFinalizzerBatch_closure`, ...). Those are Haskell, out of scope;
`base-stubs.c` defines each as `StgWord sym[8]` so a C-only driver can link.
Nothing in `hs_init`/`hs_exit`/GC-with-no-live-Haskell-objects enters them.

- `main-hsinit.c` (`hs_init`, `hs_exit` from `HsFFI.h`): links, runs, exit 0.
- `main-gc.c` (`hs_init`; `performMajorGC`; 100 000 x `allocate(16)`;
  `performMajorGC`; `hs_exit`): links, runs, exit 0. `+RTS -S` reports two
  collections and 12,800,000 bytes allocated — GC.c, the file carrying 43 of
  the 58 rewrites, plus BlockAlloc/MBlock/Storage, actually executed.
- RTS flag parsing works; note 6.2.2 writes `-s`/`-S` output to
  `<prog>.stat` by default (`RtsFlags.c:818-820`), not stderr.

A compiled-Haskell entry (`rts_evalIO` on a real closure) needs a 6.2.2
compiler and is out of scope.

## 7. Step 5: register conventions under `NO_REGS` on x86_64

With `NO_REGS` defined, `MachRegs.h` skips its entire `#ifndef NO_REGS` block
(lines 22-591), **including the x86_64 map** at 244-261 (`REG_Base rbx, REG_Sp
rbp, REG_Hp r12, REG_R1 r13, REG_SpLim r14, REG_HpLim r15`, and its explicit
`MAX_REAL_VANILLA_REG 1`). Control falls to the defaults at 608-658: no
`REG_Rn` is defined, so

```
MAX_REAL_VANILLA_REG 0   MAX_REAL_FLOAT_REG 0   MAX_REAL_DOUBLE_REG 0
MAX_REAL_LONG_REG 0      NO_ARG_REGS defined  (line 665)
```

`PrimOps.hc` **no longer** selects on `defined(REG_R8)`; it selects on the
count: `#if MAX_REAL_VANILLA_REG == 8` / `> 2 && < 8` / `== 2` / `== 1` /
`#else /* 0 Regs available */` (lines 79-201). Here the last branch is taken:
`RET_P(a)` is `PUSH(1,a); PUSHED(1)`, results go on the stack.

Compiler side (`ghc/compiler/codeGen/CgRetConv.lhs:186-193`):

```
useVanillaRegs | opt_Unregisterised = 0
               | otherwise          = mAX_Real_Vanilla_REG
```

`opt_Unregisterised` is `-funregisterised`, part of `unregFlags`
(`DriverState.hs:680-685`: `-optc-DNO_REGS -optc-DUSE_MINIINTERPRETER
-fno-asm-mangling -funregisterised -fvia-C`), applied by way `u`/`-unreg` and
by default when the compiler was built with `GhcUnregisterised=YES`
(`Main.hs:152`). `genapply` is compiled `-DNO_REGS` by its own Makefile and so
also sees 0.

So yes, the D42 item-1 mismatch is fixed **by construction** in 6.2.2: the RTS
macro and the code generator both derive from the register *count* (0), not
one from the count's default and the other from register *pinning*. The RTS as
built here (`.hc` files compiled `-DNO_REGS`) is consistent with what a
6.2.2 compiler invoked with `-funregisterised` assumes. The one way to get it
wrong is to compile the `.hc` files without `-DNO_REGS` while the compiler
runs unregisterised: then PrimOps.hc would take the `== 1` branch (R1 in
`r13`) against a caller reading the stack.

## 8. Verdict

Yes. GHC 6.2.2's RTS builds unregisterised on x86-64 with gcc 16 after one
mechanical transformation (58 cast-as-lvalue sites, the same class as D40) and
one linkage-keyword fix; there are no implicit-declaration, header, or
64-bit-size failures, configure needs no help at all, GMP detection works
against the system library, `Adjustor.c` needs no stub, and the resulting
`libHSrts.a` initialises, allocates 12.8 MB, runs two major collections and
shuts down cleanly from a C driver. The only piece a compiler-less bootstrap
must supply is `AutoApply.hc`, which is a small Haskell 98 generator that
MicroHs compiles with a pretty-printer shim. What this experiment cannot
show is runtime correctness under compiled Haskell — the D42 class of bugs
lives there — but 6.2.2 was the first GHC to know x86-64 existed, its
register-convention selection is already count-based, and every place that
was a porting problem in 4.08.2 was a non-event here.
