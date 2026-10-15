# The chain, drawn

Six views of the bootstrap chain, as Mermaid diagrams (GitHub renders them;
elsewhere, paste into any Mermaid viewer). Each is drawn from a file in this
repository, named above it, and re-read on 2026-10-01. [README.md](README.md) has the
prose; [DECISIONS.md](DECISIONS.md) has the reasons.

## 1. The whole chain, one link per compiler

From [README.md](README.md) and `default.nix`.

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
    g610["GHC 6.10.4 ... 9.14.1<br/>see section 6"]
    host --> hugs --> mhs --> tools --> s1 --> libs --> s2 --> s3 --> s4 --> s5
    s5 -. "220/220 .hc byte-identical" .-> s4
    s3 -->|"wrapped as boot;<br/>6.2.2's own make = ghc622"| g66 --> g610
```

## 2. Phase 0: the seed, Hugs to a self-hosting mhs

From `mhs/default.nix` and `mhs/bootstrap-seed.sh`. The Nix build deletes
MicroHs's shipped `generated/*.c` before anything runs; the `build/` scripts
use the shipped `mhs.c`, and [D1](DECISIONS.md#d1--the-seed-is-c-compiler--hugs-source-not-microhss-shipped-comb) is the check that the two compilers agree.

```mermaid
flowchart TB
    htar["hugs98-plus-Sep2006.tar.gz"] -->|"patches 0002, 0003<br/>gcc -std=gnu89 -fpermissive"| hugs["runhugs"]
    msrc["MicroHs source<br/>shipped generated/*.c deleted<br/>patch 0001 hugs shim"] --> hugs
    hugs -->|"interprets MicroHs.Main,<br/>which compiles itself"| gen1["generated/hmhs.c<br/>generation 1"]
    gen1 -->|"gcc + src/runtime"| hmhs["bin/hmhs"]
    hmhs -->|"compiles MicroHs.Main"| gen2["generated/mhs.c<br/>generation 2"]
    gen2 -->|"gcc + src/runtime"| mhs["bin/mhs<br/>installed"]
    mhs -->|"compiles MicroHs.Main"| gen3["gen3.c<br/>generation 3"]
    gen3 -. "cmp: must be identical" .- gen2
    seed["MicroHs's shipped generated/mhs.c<br/>used by build/, not by Nix"] -. "diverse double compilation:<br/>same C out of MicroHs (D1)" .- gen2
```

## 3. The mhs-built tools, each closed by a fixed point

From `cpphs/default.nix` and `happy/default.nix`.

```mermaid
flowchart LR
    subgraph cpphs["cpphs 1.20.9"]
        c0["gcc -E -traditional<br/>on polyparse only"] --> c1["round 1 cpphs<br/>no CPP at all"] --> c2["round 2<br/>installed"] --> c3["round 3"]
        c3 -. "C identical" .- c2
    end
    subgraph happy["happy 1.19.5"]
        hseed["happy-seed/<br/>Parser.hs, AttrGrammarParser.hs<br/>generation 2"] --> hb["happy built by mhs"] -->|"regenerates from .ly"| hregen["Parser.hs again"]
        hregen -. "cmp: byte for byte" .- hseed
    end
    mhs["mhs"] --> c1
    mhs --> hb
    c2 -->|"cpphs --noline<br/>GenericTemplate"| hb
```

## 4. GHC 6.2.2 as the Nix derivation graph

Edges are the inputs of each `ghc622/*.nix`; stdenv, python3, perl and
gmp are omitted, and an edge into a box stands for one into each derivation
in it. `ghc622/default.nix` says why there are this many steps. This
one is D2 with the TALA layout, not Mermaid: the source is
`diagrams/ghc622-derivations.d2`, and the render command is in its header.

![GHC 6.2.2 derivation graph](diagrams/ghc622-derivations.svg)

## 5. What is compared with what

The `compare3`, `compare4` and `compare5` targets of `build/Makefile`, and
[ghc622/README.md](ghc622/README.md#what-does-not-work)'s "What does not work" item 1. `stageN/*.hc` is what the stage N-1
compiler emitted.

```mermaid
flowchart LR
    s1["stage 1<br/>mhs-built, shims"] -->|compiles| s2["stage 2 .hc + ghc"]
    s2 -->|compiles| s3["stage 3 .hc + ghc-stage3"]
    s3 -->|compiles| s4["stage 4 .hc + ghc-stage4"]
    s4 -->|compiles| s5["stage 5 .hc"]
    s2 -. "compare3: differ<br/>(shim FastString uniques<br/>change local names and order)" .- s3
    s3 -. "compare4: 218/220 .hc identical,<br/>all 220 .hi identical,<br/>2 differences explained (D51)" .- s4
    s4 -. "compare5: 220/220 .hc identical<br/>the fixed point" .- s5
    s3 -. "binaries ghc-stage3 vs ghc-stage4:<br/>38 bytes (build-id, Pretty float word,<br/>one swapped SRT)" .- s4
```

## 6. The road past 6.2.2

Every GHC below is built (`ghcNN/`, [DECISIONS.md](DECISIONS.md) [D52](DECISIONS.md#d52--622-builds-itself-with-its-own-build-system-the-chain-climbs-to-6123-gmp-62-breaks-every-ghc-before-80)-[D54](DECISIONS.md#d54--hadrian-rungs-984--9124--9141-one-derivation-for-all-three-the-chain-reaches-the-newest-release)). The floor
under each release is the minimum boot compiler its `configure.ac` accepts
(read 2026-10-01); it is configure's check only, and 9.14.1 showed it can
be stale: its configure says 9.6, its stage-0 build needs 9.10's
ghc-internal, so 9.12.4 is on the ladder.

```mermaid
flowchart LR
    g622["6.2.2<br/>done"] --> g66["6.6<br/>done<br/>needs ≥ 5.04"] --> g610["6.10.4<br/>done<br/>≥ 6.4"] --> g612["6.12.3<br/>done<br/>≥ 6.8"] --> g742["7.4.2<br/>done<br/>≥ 6.12"] --> g784["7.8.4<br/>done<br/>≥ 7.4"] --> g802["8.0.2<br/>done<br/>≥ 7.8"] --> g844["8.4.4<br/>done<br/>≥ 8.0"] --> g884["8.8.4<br/>done<br/>≥ 8.4"] --> g902["9.0.2<br/>done<br/>≥ 8.8"] --> g948["9.4.8<br/>done<br/>≥ 9.0, make kept for a boot < 9.1"] --> g984["9.8.4<br/>done<br/>≥ 9.4, Hadrian"] --> g9124["9.12.4<br/>done<br/>≥ 9.6"] --> g9141["9.14.1<br/>done<br/>configure says ≥ 9.6, stage 0 needs ≥ 9.10"]
    subgraph g66parts["built by 6.2.2 for 6.6"]
        h116["happy 1.16<br/>seedless fixed point"] --> a210["alex 2.1.0<br/>Scan.hs by fixed point"]
    end
    g66parts --> g66
```
