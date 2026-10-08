# Bootstrapping GHC: state of the art and a plan

*Written 2026-09-02; status notes added 2026-09-15, marked **Status**. The plan
below is kept as written; DECISIONS.md is the record of what actually happened.
Sources: Breitner [748](https://www.joachim-breitner.de/blog/748-Thoughts_on_bootstrapping_GHC)
and [802](https://www.joachim-breitner.de/blog/802-More_thoughts_on_a_bootstrappable_GHC),
Wurmus [Bootstrapping Haskell part 1](https://elephly.net/posts/2017-01-09-bootstrapping-haskell-part-1.html),
the Discourse thread [What's needed to bootstrap GHC with hugs?](https://discourse.haskell.org/t/what-s-needed-to-bootstrap-ghc-with-hugs/6205),
[nomeata/bootstrapping-haskell](https://github.com/nomeata/bootstrapping-haskell), and
[MicroHs](https://microhs.org/).*

## The problem

Every GHC needs an older GHC. `ghc/configure.ac:217` sets `MinBootGhcVersion="9.10"` for
today's master (9.15). The chain runs back to GHC 0.29 (1996), which was built with HBC,
which is written in LML, which needs LML. Some old GHC tarballs ship generated ANSI C, but
generated code is not source: using it makes the root of the chain a binary-equivalent seed.

Three distinct goals get conflated, and they want different solutions:

- **purity** — a bootstrappable.org-style chain from a tiny auditable seed;
- **trust** — resistance to a Thompson-style attack in the binary chain;
- **practicality** — bringing GHC up on a new architecture.

## The four approaches

### 1. Historical retracing (walk the chain from the origin)

Dismissed at the root by Breitner (748): HBC needs LML, and 1990s code does not build with
2020s toolchains. The *upper* chain is real, partly-done work, though. Guix (rekado) has:

- `4.08.2 -> 6.0 -> 6.6 -> 6.10.4`
- `7.8.4 -> ... -> 9.4.4`
- a gap in between (the 6.12.3 / 7.4.2 era)

Guix's 4.08.2 is built **from the pre-generated C in the tarball**, so this chain still has a
binary-equivalent seed at its root. Necessary work; not sufficient.

> **Status (2026-10-03).** The upper chain is done here, from this repository's
> seedless 6.2.2: 6.6 → 6.10.4 → 6.12.3 → 7.4.2 → 7.8.4 → 8.0.2 → 8.4.4 →
> 8.8.4 → 9.0.2 → 9.4.8 (make) → 9.8.4 → 9.12.4 → 9.14.1 (Hadrian), every
> rung a `nix-build -A ghcNN` built by the one before it; the 6.12.3 / 7.4.2
> gap Guix left open is closed (D52), and 9.14.1 is the newest release
> (DECISIONS.md D52–D54, README "What works").

### 2. Hugs -> nhc98 -> early GHC (rekado, 2017)

Hugs is the one still-buildable Haskell implementation written in C. rekado ran the *nhc98
compiler itself* as a script under `runhugs`, faking `nhc98comp` with a shell wrapper, and got
the nhc98 prelude built — via detours through `cpphs` and GreenCard, both also run under Hugs.

Stalled on: nhc98 is 32-bit only; its RTS misbehaves on modern x86-64; and it was never shown
that nhc98 can build *any* GHC.

### 3. Run GHC's own source under Hugs (Breitner, 802)

The blocker Hugs cannot clear is **mutually recursive modules**. Alistair Reid: *"I almost had
it supporting mutually recursive modules but I couldn't quite get all the dependencies in the
typechecker under control."*

Breitner sidesteps it with `hs-all-in-one`, which flattens all of GHC into a single module
(`haskell-src-exts` to parse, `haskell-names` to resolve, Haddock `.txt` files to fully qualify
imports). Result: a **680,000-line, 41 MB single file that GHC's own parser accepts**.

Remaining obstacles: GHC's compiler source reaches into RTS internals via `base`;
primops and unboxed types; FFI; and Hugs is Haskell 98 + a few extensions only.
Target version floated: **4.08.2**, which docks with Guix's existing chain.

### 4. Write a new bootstrappable compiler

In 2017 this was "a lot of work, nobody will do it". **This has since happened, for unrelated
reasons.**

## What changed: MicroHs is the missing seed

[MicroHs](https://microhs.org/) (Augustsson; 0.16.x, 2026) is a maintained, self-hosting
compiler for an extended subset of Haskell 2010, compiling via combinators to C. Two properties
matter here, both verified in the source rather than taken from the thread:

- **It handles mutually recursive modules.** `src/MicroHs/Compile.hs:195` reads `.hs-boot`
  files, GHC-style. The hardest Hugs blocker simply does not apply.
- **It has a Hugs bootstrap path.** The `Makefile` carries a `hugs/` override tree and a target
  that runs the MicroHs compiler *under Hugs* to regenerate its own C:

      runhugs '+Phugs:src:{Hugs}/packages/*:hugs/obj' -98 +o +w -h100m \
        hugs/Main.hs -imhs -isrc MicroHs.Main -ogenerated/hmhs.c

  So the shipped `generated/mhs.comb` need not be a required binary seed: the seed can be
  **C compiler + Hugs source only**.

The open question is therefore no longer "is there a seed" but "how do we get from that seed
to a GHC".

> **Update, after running Phase 0 (2026-09-02).** The claim above was first too strong, then
> too weak. MicroHs's Hugs path did not run on master: it died on **pattern guards**, which Hugs
> does not implement, in ~200 places. That feature is now implemented
> (`hugs/patches/0002-hugs-pattern-guards.patch`), along with a MicroHs shim patch and a raise
> of two Hugs stack limits. **The seed now works and has been verified**: C compiler + Hugs source
> produces a native MicroHs that reaches a byte-identical fixpoint, and that emits byte-identical
> output to the compiler built from MicroHs's shipped pre-generated C. The pre-generated
> combinator file is therefore no longer in the trusted base.
> Details: [`notes/phase0/FINDINGS.md`](notes/phase0/FINDINGS.md); reproduce with `mhs/bootstrap-seed.sh`.

## Plan

Combine approaches 3 and 4; treat 1 as separable work that pays off regardless.

### Phase 0 — verify the seed (days) — **DONE, see `notes/phase0/FINDINGS.md`**

Build Hugs from source, then `make bin/hmhs` in MicroHs; confirm the Hugs-generated `hmhs.c`
yields a compiler that fixpoints against `make bootstrap`. Success gives an auditable root:
C compiler + Hugs source -> working Haskell compiler. Failure is itself high-value: this is an
off-the-beaten-path target that may have rotted, and the fix is small and worth upstreaming.

Outcome: it had rotted. Hugs builds clean on GCC 16 with three mechanical fixes
(`hugs/build-hugs.sh`); MicroHs's shim needed a one-line fix; then it stops at pattern
guards. **The next task is to implement pattern guards in Hugs** — `parser.y:616` and
`parser.y:875` need the existing `quals` production, and `machine.c:buildGuards`/`makeTests`
need fall-through for a failing guard pattern. Contained C work in one or two files, and much
smaller than the recursive-modules problem, which does not arise here because MicroHs handles
mutual recursion itself via `.hs-boot`.

### Phase 1 — pick the target GHC empirically (a few weekends) — **DONE, twice**

> **Status.** Measured 2026-09-02 (`notes/phase1/FINDINGS.md`, D2): 4.08.2 scored
> best on every axis that matters to mhs (smallest source, 3 modern-extension
> hits against 21 for 6.0, no library gap, no shipped generated code), so the
> plan's hypothesis that a newer GHC would score far better was wrong. What
> made 6.x look out of reach later was one macro, `SLIT` over unboxed string
> literals (D44); once it was redefined over boxed `String` (D45, 2026-09-09)
> 6.0 went from 12 to 214 modules and the entry point moved to **6.2.2**, the
> first GHC with an x86-64 port. The second criterion below (a via-C backend
> needing only gcc) is exactly what made 6.2.2 usable.

Do not assume 4.08.2. Write a mechanical inventory tool that walks the source of each candidate
(4.08.2, 5.04, 6.0, 6.10.4) and reports: extensions used, primops referenced, `base`/RTS
internals imported, CPP usage, recursive-module clusters. Score against what `mhs` accepts.

4.08.2 is attractive *only* because it docks with Guix's chain; if 6.x scores far better, the
extra hops are cheaper than the extra features. Second criterion: the candidate needs a working
unregisterised / via-C backend so its output needs only gcc. (Modern GHC still has
`compiler/GHC/CmmToC.hs`; old GHCs had `-fvia-C`.)

### Phase 2 — the compat layer, as two separate problems — **DONE**

> **Status.** Both halves exist for both targets: the shims in
> `common/shims`, `ghc622/shims-*` and `ghc622/shims`, and the patch series in
> `notes/phase2`+`notes/phase3` (30 patches, 4.08.2) and `ghc622/patches` (26 patches, 6.2.2),
> each checked to reproduce its working tree from the pristine tarball.
> Flattening was indeed unnecessary: mhs reads the `.hs-boot` files converted
> from GHC's `.hi-boot` (`notes/phase2/hiboot2hsboot.py`).

1. A `ghc-on-mhs` shim package providing what the old compiler's modules import from its own
   `base`/RTS, implemented over MicroHs's `lib/`.
2. A quilt-style patch series against the pristine tarball for language-level gaps.

Keeping these as patches over an unmodified upstream tarball is what makes the result auditable
rather than "a fork that happens to compile". Note that Breitner's flattening is probably
*unnecessary* here, given `.hs-boot` support — a large simplification over the Hugs plan.

### Phase 3 — close the loop — **half done**

> **Status.** The old GHC runs under mhs and emits C: GHC 6.2.2's compiler
> proper, linked by mhs, compiled all 147 modules of its own `base`, and a
> compiled program prints `hello` on 6.2.2's own RTS (D47, D48, 2026-09-10).
> The self-hosting half, 6.2.2 compiling its own compiler to a native binary,
> is started and interrupted at 80 of 220 modules (D49,
> `build/ghc622-stage2`). On 4.08.2 the loop cannot close: the 1999 runtime
> has 64-bit bugs no one ever hit (D42).

Run the old GHC under `mhs`, unregisterised, to emit C for itself; compile that with gcc; get a
native GHC that self-hosts. Then we are on the chain.

### Phase 4 — fill the Guix gap, 6.10.4 -> 7.8.4 (parallel, independent) — **not started**

> **Status.** Untouched. Note that `notes/phase4/` in this repo is *not* this
> phase: it holds the 6.2.2 reproduction (README "Layout"). Entering at 6.2.2
> rather than 4.08.2 also skips the first two hops of Guix's chain.

Grind, not research. Proceeds without any of the above, and without it the seed work dead-ends
at 6.10.4.

### Fallback branch: Core lowering — **not needed**

jeffstyr's idea from the thread: have a modern GHC emit a simplified, explicitly
dictionary-passing, Core-derived Haskell rendering of GHC itself, and compile *that* with `mhs`.

Not a bootstrap — the generator is GHC — but the output is human-readable source that can be
diffed and audited, and combined with diverse double compilation it buys most of the *trust*
without the *purity*. If Thompson-attack resistance is the actual goal, this is far cheaper
than Phases 1-3.

## Working notes

- There is no modern GHC checkout in this repo. The working trees are the old GHC
  tarballs in the root (4.08.2, 5.00.2, 6.0, 6.2, 6.2.2, 6.10.4), the Hugs tarball, and
  `MicroHs/`. The machine's own GHC was used once as a one-time generator and
  discharged (D7); the reproduction scripts run with a PATH that holds no `ghc`.
