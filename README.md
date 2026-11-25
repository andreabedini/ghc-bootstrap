# Bootstrapping GHC from source

This repository builds GHC 9.14.1 starting from a C compiler and the source code of Hugs. Every compiler in the
chain is built from source by the one before it. There is no Haskell binary
to trust, and generated code stands in for source only in the few places I
list in [What the chain trusts](#what-the-chain-trusts).

By "bootstrapping" I mean what [bootstrappable.org](https://bootstrappable.org)
means: the trusted base is a C toolchain and source code, not a pre-built
binary. "Bootstrapping GHC with Hugs" is on their
[list of projects](https://bootstrappable.org/projects.html). This is not about porting
GHC to a new platform, nor about rebuilding GHC with a GHC you already have.

I relied on Claude (Anthropic's coding agent) for most of the grunt work:
running the probes, chasing build failures, writing patches and Nix
derivations, and keeping the notes. The decisions that stand are in
[`DECISIONS.md`](DECISIONS.md); how we reached them is in the commit history.

## TL;DR

```sh
nix-build -A ghc914              # Hugs -> MicroHs -> GHC 6.2.2 -> ... -> GHC 9.14.1
nix-build -A ghc622.fixpoint     # GHC 6.2.2 up to stage 5, and the fixed-point check
```

Every link is an attribute of `default.nix` (`hugs`, `mhs`, `cpphs`, `happy`,
`gmp612`, `ghc622`, `ghc66`, ... `ghc914`). nixpkgs is pinned, and every other
input is a tarball or commit fetched by hash and listed in [`SOURCES.md`](SOURCES.md). I have
only built it on x86-64 Linux.

## Why this route

Every GHC needs an older GHC; today's master asks for 9.10. If you follow the
chain back you end up at GHC 0.29 (1996), built with HBC, which is written in
LML. Some old GHC tarballs ship generated C, but generated code is not source:
starting from it just moves the binary seed somewhere less visible.

Four other approaches have been proposed
([Breitner 748](https://www.joachim-breitner.de/blog/748-Thoughts_on_bootstrapping_GHC),
[Breitner 802](https://www.joachim-breitner.de/blog/802-More_thoughts_on_a_bootstrappable_GHC),
[Wurmus 2017](https://elephly.net/posts/2017-01-09-bootstrapping-haskell-part-1.html),
[the Discourse thread](https://discourse.haskell.org/t/what-s-needed-to-bootstrap-ghc-with-hugs/6205)):

1. **Walk the historical chain.** Dead at the root: HBC needs LML, and 1990s
   code does not build with 2020s toolchains. Guix has the upper part, from a
   4.08.2 built from the tarball's generated C, with a gap around 6.12 and 7.x.
2. **Hugs -> nhc98 -> early GHC** (Wurmus, 2017). nhc98 is 32-bit only, and
   nobody has shown it can build any GHC.
3. **Run GHC's own source under Hugs** (Breitner, 802). Hugs cannot do
   mutually recursive modules, so GHC has to be flattened into a single
   680,000-line module, and GHC's compiler reaches into RTS internals through
   `base`, primops and unboxed types, the FFI, while Hugs only speaks Haskell
   98.
4. **Write a new bootstrappable compiler.** Somebody did, for other reasons:
   [MicroHs](https://microhs.org/).

MicroHs is the missing seed. It is maintained and self-hosting, it compiles via
combinators to C, and it reads `.hs-boot` files, so mutual recursion is not a
problem. It has a path that runs its own compiler under Hugs, which needs
pattern guards in Hugs; I add them to Hugs rather than rewriting MicroHs's
source ([D18](DECISIONS.md#d18--hugs-is-patched-for-pattern-guards-not-microhss-source)), so the seed is a C compiler and Hugs source only. The
Hugs-built MicroHs reproduces MicroHs's own shipped C byte for byte ([D1](DECISIONS.md#d1--the-seed-is-a-c-compiler-and-hugss-source-not-microhss-shipped-c)).

mhs then compiles GHC 6.2.2, the first release with an x86-64 port
(unregisterised, via C). Older GHCs assume a 32-bit machine in their runtime,
and 6.x is reachable once one macro, `SLIT`, is redefined over boxed strings
([D45](DECISIONS.md#d45--the-mhs-entry-point-is-ghc-622)). GHC's source compiles under mhs with a shim layer and a patch series
over the pristine tarball; it does not need flattening.

## The chain

```mermaid
flowchart LR
    host["Host: C toolchain<br/>gcc, binutils, glibc, GMP<br/>sh, make, tar, perl, python3"]
    hugs["Hugs 98 (Sep 2006)<br/>patches 0002, 0003"]
    mhs["MicroHs (mhs)<br/>gen 1 interpreted by Hugs<br/>gen 2 == gen 3"]
    tools["cpphs, happy 1.19.5, hsc2hs<br/>compiled by mhs"]
    s1["GHC 6.2.2 stage 1<br/>compiler proper, run on<br/>the MicroHs runtime"]
    libs["rts, base, haskell98<br/>compiled by stage 1 + gcc"]
    s2["GHC 6.2.2 stage 2<br/>native"]
    s3["stage 3"]
    s4["stage 4"]
    s5["stage 5<br/>.hc only"]
    g66["GHC 6.6<br/>configure + make<br/>happy 1.16, alex 2.1.0"]
    g610["6.10.4"]
    g612["6.12.3<br/>registerised from here"]
    g74["7.4.2"]
    g78["7.8.4<br/>last on GMP 6.1.2"]
    g80["8.0.2"]
    g84["8.4.4"]
    g88["8.8.4<br/>GHCi + SMP from here"]
    g90["9.0.2"]
    g94["9.4.8<br/>last with make"]
    g98["9.8.4<br/>Hadrian from here"]
    g912["9.12.4"]
    g914["9.14.1<br/>newest release"]
    host --> hugs --> mhs --> tools --> s1 --> libs --> s2 --> s3 --> s4 --> s5
    s5 -. "220/220 .hc byte-identical" .-> s4
    s3 -->|"wrapped as boot;<br/>6.2.2's own make = ghc622"| g66 --> g610 --> g612 --> g74 --> g78 --> g80 --> g84 --> g88 --> g90 --> g94 --> g98 --> g912 --> g914
```

Each link has its own directory, with the derivation, every file it reads, and
a README:

| Link | Built by | Build system | What it needed on a 2026 host (gcc 15, glibc 2.42, binutils 2.46) |
|---|---|---|---|
| [Hugs 98](hugs/README.md) | gcc | configure, make | pattern guards; permissive C flags in `CC` |
| [MicroHs 0.17.0.0](mhs/README.md) | Hugs, then itself | | generation 3 equals generation 2; the shipped C is deleted |
| [cpphs 1.20.9](cpphs/README.md) | mhs | three rounds, from gcc's cpp to a fixed point | |
| [happy 1.19.5](happy/README.md) | mhs | | its own parsers, by fixed point and by diverse double compilation from happy 1.15 |
| [GMP 6.1.2](gmp612/README.md) | gcc | configure, make | for every GHC before 8.0 ([D52](DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-every-ghc-before-80-gets-gmp-612)) |
| [GHC 6.2.2](ghc622/README.md) | mhs, then itself to a fixed point | by hand up to stage 3, then its own `configure && make` | 25 patches for mhs; RTS patches, `gen-htypes`, `_GNU_SOURCE`, a happy wrapper |
| [GHC 6.6](ghc66/README.md) | 6.2.2 | make | parsers regenerated with happy 1.16 and alex 2.1.0 built by 6.2.2 |
| [GHC 6.10.4](ghc610/README.md), [6.12.3](ghc612/README.md) | 6.6, 6.10.4 | make | plain `ar` for libffi; `__GNUC__ > 4` blocks in `Rts.h`; registerised with NCG from 6.12 |
| [GHC 7.4.2](ghc74/README.md), [7.8.4](ghc78/README.md) | 6.12.3, 7.4.2 | make | `-std=gnu89 -fpermissive -fwrapv`; `DYNAMIC_* = NO`; happy 1.19.5 and alex 3.2.7.4 built by 7.4.2 |
| [GHC 8.0.2](ghc80/README.md), [8.4.4](ghc84/README.md) | 7.8.4, 8.0.2 | make -j | `-std=gnu11`; `CC=gcc` (8.4); the host's GMP from here |
| [GHC 8.8.4](ghc88/README.md), [9.0.2](ghc90/README.md) | 8.4.4, 8.8.4 | make -j | `GHC=`; GHCi and SMP; StgCRunAsm patch; `--with-gmp-*` (9.0) |
| [GHC 9.4.8](ghc94/README.md) | 9.0.2 | make -j (9.4 keeps make for a boot < 9.1) | happy 1.20.1.1 built by 9.0.2 for `build-tool-depends`; python3 |
| [GHC 9.8.4](ghc98/README.md) | 9.4.8 | Hadrian, bootstrapped by `bootstrap.py` from a plan with Nix-fetched sources | hp2ps C23 patch (upstream, in 9.10) |
| [GHC 9.12.4](ghc912/README.md) | 9.8.4 | Hadrian | nothing beyond the plan |
| [GHC 9.14.1](ghc914/README.md) | 9.12.4 (its configure says 9.6, stage 0 needs 9.10) | Hadrian | the ghc-9.14 branch's `Binary HalfWord` guard |

Each GHC is the newest release that accepts the previous one as its boot
compiler. Each one passes `common/test/T3.hs` and whatever checks its
derivation names ([D52](DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-every-ghc-before-80-gets-gmp-612)-[D54](DECISIONS.md#d54--one-hadrian-derivation-for-984-9124-and-9141)). From 8.8 on the compilers have the standard
configuration: registerised, native code generator, GHCi, SMP, static
libraries. A `-threaded` program they compile links outside Nix and runs with
`-N`.

GHC 6.2.2 is the step that matters. mhs compiles its compiler proper, that
compiler builds 6.2.2's runtime and libraries, and then it compiles its own
source. By stage 5 the Abstract C is byte-identical to stage 4's in all 220
modules ([D45](DECISIONS.md#d45--the-mhs-entry-point-is-ghc-622)-[D51](DECISIONS.md#d51--the-622-fixed-point-stage-5-equals-stage-4-in-all-220-modules)). The [ghc622 README](ghc622/README.md) has the stages, the
patch series and what still does not work.

## What the chain trusts

bootstrappable.org explains the [benefits](https://bootstrappable.org/benefits.html)
as provenance: the dependency graph shows how every binary was obtained. And
its [best practices](https://bootstrappable.org/best-practices.html) ask a
self-hosted compiler to stay buildable by a different implementation of its
language. No other Haskell implementation can build today's GHC, so Hugs and
MicroHs play that role here, by way of GHC 6.2.2. This is the full list of what the chain still takes on trust:

- **No Haskell implementation from outside the chain.** Generated code stands
  in for source only where this list says, and I discharged or checked each
  case ([D55](DECISIONS.md#d55--generated-code-in-the-inputs-parsers-and-lexers-are-regenerated-from-their-grammars)):
  - **happy's parser, discharged.** The first portable happy parser came out
    of a happy built with my machine's GHC 9.14. `happy-mhs` then regenerated
    it, and generation 3 is byte-identical to generation 2, so the GHC-built
    happy leaves the trusted base ([D7](DECISIONS.md#d7--happys-seed-is-a-ghc-built-happys-output-discharged-twice), [D14](DECISIONS.md#d14--happy-is-verified-by-regeneration-not-by-equality-with-a-ghc-built-happy)). A fixed point
    alone would be weaker than [diverse double compilation](https://dwheeler.com/trusting-trust/),
    so I also start from an unrelated seed: the parser happy 1.14 wrote, which
    happy's repository commits at the `Happy_1_15` tag. happy 1.15 built from
    it, by way of a happy 1.19.5, gives the same seed byte for byte
    (`nix-build -A happy.ddc115`, [D56](DECISIONS.md#d56--happys-seed-by-diverse-double-compilation-from-happy-115);
    the idea and the patch for 1.15 are Alexandre Tunstall's, [#2](https://github.com/andreabedini/ghc-bootstrap/issues/2)).
  - **MicroHs's shipped C, checked.** The Nix build deletes MicroHs's
    `generated/*.c` before anything runs. Its check phase then requires the
    Hugs-derived `mhs`, run as MicroHs's Makefile runs it (`-z`), to reproduce
    the shipped `generated/mhs.c` byte for byte, and it does. The scripts under `build/` run
    `MicroHs/bin/mhs`, compiled from 0.16.8.0's shipped C. As a compiler it is
    equivalent to the Hugs-derived one, but it is not the same binary ([D1](DECISIONS.md#d1--the-seed-is-a-c-compiler-and-hugss-source-not-microhss-shipped-c)).
  - **cpphs, checked.** The Nix build builds cpphs from source with mhs, with
    gcc's traditional cpp standing in for the first round. The source-built
    cpphs and MicroHs's shipped one give identical output on every `.hs`,
    `.lhs` and `.pp` file of GHC 6.2.2 with the chain's three flag sets (1,458
    runs). The `build/` scripts run the shipped one. From 6.2.2's stage 2 on,
    GHC's own `-cpp` uses gcc.
  - **alex's own lexer, discharged.** alex 2.1.0 and 3.2.7.4 start from
    the `Scan.hs` their tarballs ship, which only an alex can produce. The alex
    built from it has to regenerate it from `Scan.x`, and a second generation
    has to reproduce the first byte for byte. That is only a fixed point, and
    an mhs-built alex regenerating the `Lexer.hs` GHC 6.2.2 ships would not
    settle it either: as Janus Troelsen pointed out
    ([#102](https://discourse.haskell.org/t/what-s-needed-to-bootstrap-ghc-with-hugs/6205/102)),
    that alex still runs alex's own generated `Scan.hs`, probably made by the
    same alex that made `Lexer.hs`. So, as with happy, there is a
    second starting point that no alex made: a scanner for alex 2.1.0 written
    by hand from `Scan.x`'s rules. The alex 2.1.0 built from it regenerates the
    tarball's `Scan.hs`, and an alex built from that output regenerates it byte
    for byte (`nix-build -A ghc66.alex210ddc`). alex 2.1.0 accepts 3.2.7.4's
    `Scan.x` as it is, so the same alex makes 3.2.7.4's `Scan.hs`, and the alex
    3.2.7.4 built from it gives the tarball's `src/Scan.hs` byte for byte
    (`ghc66.alexChain`). Each of the two alexes the GHCs are built with agrees
    byte for byte with its counterpart from the hand-written scanner on every
    alex grammar of GHC 6.6 to 9.14.1 (`ghc66.alexChainLexers`,
    [D57](DECISIONS.md#d57--alexs-own-lexer-by-diverse-double-compilation-from-a-hand-written-scanner)).
    The alex 3.5.2.0 in Hadrian's bootstrap plan is built from its shipped
    `Scan.hs` without any of these checks.
  - **happy 1.16, 1.19.5, 1.19.12 and 1.20.1.1**, built by the GHCs that need
    them, have their parsers regenerated from the grammars by the chain's
    happy, compared with the shipped ones, and taken to a fixed point.
  - **GHC 6.2.2's `parser/Lexer.hs`, used as shipped, checked.** It is alex
    2.0's output, which `convert-lexer.py` rewrites over boxed arrays.
    `Lexer.x` is in the tarball, but no alex exists before 6.2.2 is built.
    The alex 2.1.0 from the hand-written scanner, run on that `Lexer.x`, gives
    the same DFA (the four tables and the accepting states) and the same
    Haskell up to alex's template, which alex 2.0 and 2.1.0 write differently
    (`ghc66.alex210ddc`, D57). 6.2.2's three parsers and its primop tables are
    regenerated.
  - **The parsers and lexers of every GHC from 6.6 on, regenerated.** GHC's
    tarballs ship every happy and alex output the build needs. From 6.10 on,
    `common/regen-parsers.sh` gives the grammars their names back, so the
    tarball's own rules regenerate them with a happy and alex from the chain.
    Cabal's lexer (8.4 to 9.8) is regenerated the same way, and
    `common/cmp-regenerated.sh` compares each result with the shipped file.
- **A C toolchain**: gcc, binutils, glibc, and the system GMP, which is linked
  into every program.
- **Nothing pre-built from a tarball.** Two source tarballs carry build
  products: 7.4.2's `utils/ghc-pwd/dist-boot` and 9.0.2's
  `libraries/containers/.../dist-install`. Neither is used, and both
  derivations delete them before anything runs.
- **`configure` scripts as the tarballs ship them.** Every `configure` the
  chain runs (GHC's, its libraries', GMP's, Hugs's) is autoconf output, run as
  shipped. The Hadrian builds (9.8.4 on) regenerate the libraries' ones, as Hadrian does.
  Guix and nixpkgs do the same, while Debian regenerates with
  `dh_autoreconf`. bootstrappable.org's best practices say nothing about it.
  Regenerating would mean taking each release's `configure.ac` and `m4/` from
  upstream's history and running an autoconf of the right era. Even that would
  not catch an xz-style payload on its own, since that one rode in the
  tarball's `m4/`. I don't regenerate them.
- **Build tools** that run the scripts in this repository: `sh`, `make`, `tar`,
  `perl` (one RTS fix-up script) and `python3`. Python puts bytes into the
  compiler in two places:
  - `comb2c.py` writes mhs's combinator output for the stage-1 compiler as the
    C array `mhs -o ghc.c` would have written;
  - `convert-lexer.py` decodes the alex lexer's tables.

  It also generates the module order and dependencies, and checks interfaces.

## Repository layout

| Path | What it is |
|---|---|
| `default.nix` | the chain as Nix derivations, one attribute per link |
| [`hugs/`](hugs/README.md), [`mhs/`](mhs/README.md), [`cpphs/`](cpphs/README.md), [`happy/`](happy/README.md), [`gmp612/`](gmp612/README.md) | the seed and its tools |
| [`ghc622/`](ghc622/README.md) | GHC 6.2.2, the entry point: the stages, the patch series, the shims |
| [`ghc66/`](ghc66/README.md) ... [`ghc914/`](ghc914/README.md) | one directory per GHC release, each with its derivation and every file it reads |
| [`common/`](common/README.md) | what several links share: the ghc-on-mhs shims, the parser regeneration, the Hadrian build, the test programs |
| [`build/`](build/README.md) | the 6.2.2 chain by hand, without Nix: a Makefile, its scripts and the tables they read |
| [`DECISIONS.md`](DECISIONS.md) | the decisions that stand, [D1](DECISIONS.md#d1--the-seed-is-a-c-compiler-and-hugss-source-not-microhss-shipped-c)-[D59](DECISIONS.md#d59--repository-files-describe-the-current-state-history-is-in-commit-messages); the history is in `git log` |
| [`DIAGRAMS.md`](DIAGRAMS.md), `diagrams/` | the chain as six diagrams |
| [`SOURCES.md`](SOURCES.md) | where every input comes from, with hashes |
| `mise.toml` | sets `GHC_BOOTSTRAP_ROOT` for the scripts in `build/` |
| `LICENSE` | BSD 3-Clause, for what I wrote; see [Licence](#licence) for the patches |

## Licence

What I wrote here (the scripts, Nix expressions, shims and
documentation) is under the BSD 3-Clause licence in `LICENSE`.

The patches, and the few files copied or generated from an upstream source,
are derived from that project and stay under its licence:

| Upstream | Licence | Files here |
|---|---|---|
| GHC | the Glasgow Haskell Compiler License (BSD-style) | `ghc622/patches/`, `ghc622/rts/patches/`, `ghc622/hsc2hs/Main.hs.patch`, `ghc622/stage2/fixups/parser/Ctype.lhs.patch`, `ghc622/tools/genprimopcode-Main.hs.patch`, `ghc66/`, `ghc90/`, `ghc98/` and `ghc914/` `*.patch`; the Hadrian plans `plan-bootstrap-*.json` in `ghc98/`, `ghc912/` and `ghc914/` |
| Hugs 98 | the Hugs 98 licence (BSD-style) | `hugs/patches/` |
| MicroHs | Apache License 2.0 | `mhs/patches/` |
| happy | the Happy licence (BSD-style) | `happy/happy-seed/` (generated by happy from happy 1.19.5's grammars), `happy/ddc115/happy-1.15-mhs.patch` (Alexandre Tunstall's, from issue #2) |
| alex | BSD 3-Clause | `ghc66/alex210ddc/alex-2.1.0-mhs.patch`, `ghc66/alexchain/alex-3.2.7.4-mhs.patch`; `ghc66/alex210ddc/Scan.hs`, which copies `Scan.x`'s Haskell parts |
| cpphs | LGPL 2.1 (library), GPL 2 (program) | `cpphs/cpphs-1.20.9-mhs.patch` |
| polyparse | LGPL 2.1 | `cpphs/polyparse-1.12-mhs.patch` |

`ghc90/StgCRunAsm-only-when-needed.patch` and `ghc98/hp2ps-C-gnu17.patch` are
upstream GHC changes by the authors named in their headers. The upstream
sources themselves are not in this repository; [`SOURCES.md`](SOURCES.md) says where each
one comes from.
