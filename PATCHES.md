# The patch sets

Two series, one per tarball. Neither edits a source in place: each is applied
to a clean extraction and checked to reproduce the working tree.

- **GHC 4.08.2**, 30 patches in `notes/phase2/patches` and `notes/phase3/patches` (the
  retired first chain, DECISIONS.md D1–D42). Sections 1–4 below.
- **GHC 6.2.2**, 26 patches in `ghc622/patches` (the current entry point,
  D45–D48). Section 5; the per-patch table and the tooling that derives the
  series from the tree are in `notes/phase4/FINDINGS.md` section 4.

## The 4.08.2 series

30 patches against the pristine GHC 4.08.2 source release. Applying all of them to
a clean extraction reproduces the working tree byte for byte.

They fall into four groups, and the groups are the interesting part: only one of
them is about bootstrapping at all.

## 1. Haskell that stopped being legal (0002-0018, 0022)

GHC 4.08.2 is written in the Haskell of 1999 and compiled here by `mhs`, which
implements a much later language. These are not bugs in GHC; they are the
language moving.

| Patch | What |
|---|---|
| 0002 | `SLIT(x)` produced an unboxed string literal; rewritten to `mkFastString`, removing 2,021 of them |
| 0003 | array indexing that assumed a particular `Ix` instance |
| 0004 | base-62 encoding using non-portable arithmetic |
| 0005, 0007 | unboxed character literals, including named escapes |
| 0006 | the `Eval` class, which no longer exists |
| 0008 | `Ctype.lhs` is Latin-1; transcoded |
| 0009 | `_scc_` cost-centre annotations |
| 0010 | `UniqSupply`'s `mk_supply#` is a CAF, and mhs memoises `unsafeInterleaveIO` where GHC re-executes it |
| 0011, 0013, 0015 | nine duplicate import items — a genuine GHC bug that its own compiler tolerated |
| 0012 | Applicative-Monad Proposal instances |
| 0014, 0016 | composition `.` now parses as `OverloadedRecordDot` without spaces |
| 0017 | float bit-casts |
| 0018 | `<>` is now `Semigroup` |
| 0022 | `Char#` pattern synonym import |

## 2. C that stopped being legal (0019-0021, 0027, 0028)

1999 C meeting a 2020s compiler.

| Patch | What |
|---|---|
| 0019 | `CLOSURE_TBL` declares a table `const`, `EDCP_` declares it without — accepted by 1999 gcc |
| 0020 | `mulIntCzh` is missing a `\|\|`. Dead on 32-bit, wrong on 64-bit |
| 0021, 0027, 0028 | 33 uses of GCC's cast-as-lvalue extension, removed in GCC 4.0. Rewritten as `*(T*)&lv = v`, the standard-C spelling of what the extension meant |

## 3. x86-64, which did not exist in 1999 (0023-0026, 0029, 0030)

The most interesting group. GHC 4.08.2 has no entry for this architecture
anywhere, so wherever "32-bit" and "correct" coincided, the code is silently
wrong here and nothing selects a working alternative.

| Patch | What |
|---|---|
| 0023 | `config.sub` rejects the triple outright |
| 0024 | `configure`'s platform whitelist. Added a real `x86_64` case rather than masquerading as i386 — no 1999 code has an `x86_64_TARGET_ARCH` branch, so arch-specific paths correctly switch *off*, which is what unregisterised means |
| 0025 | 18 defects in the `#if WORD_SIZE_IN_BYTES == 8` sections of `Int.lhs` and `Word.lhs`, which no one had ever compiled |
| 0026 | `PrelAddr.lhs` branches on `WORD_SIZE_IN_BYTES` and includes no header at all, so it silently took the 32-bit branch and disagreed with `Word.lhs` about the representation of `Word64` |
| 0029 | `Words-1` where `Words` is 32-bit unsigned and the loop variable is a 64-bit signed: `+4294967295` instead of `-1` |
| 0030 | when `StgFloat` *is* `StgDouble`, `__encodeFloat` is never compiled but is still called. The header already aliases the decode direction and simply omits the encode direction |

Patch 0028 also carries the primop return convention: `PrimOps.hc` selects it by
asking whether STG registers are pinned to machine registers, while the compiler
selects by `MAX_REAL_VANILLA_REG`, which defaults to 8 for an unknown platform.
On x86-64 they disagreed, so primops returned results where nobody read them.

## 4. Bootstrapping proper (0001)

| Patch | What |
|---|---|
| 0001 | `unlit` rejects a trailing space after `\begin{code}` |

That is the whole of it. **One patch out of thirty is about bootstrapping.** The
other 29 are a 1999 program meeting a 2026 toolchain and a machine word twice
the size it expects.

## 5. The 6.2.2 series (`ghc622/patches`, 26 patches, 257 hunks, 102 files)

Same tree of concerns, different proportions. 6.2.2 knows x86-64 exists, so
the group that dominated 4.08.2 is gone; what remains is almost entirely the
Haskell of 2004 meeting the Haskell mhs implements.

| group | patches | what |
|---|---|---|
| Haskell that stopped being legal | 0002, 0005, 0007-0017, 0019-0022 | `SLIT`/`FSLIT` over boxed `String` (the D44 blocker, 13 hunks); `Ctype.lhs` transcoded from Latin-1 (mhs's lexer wants UTF-8); `_scc_`; `do { ;`; double and trailing commas; duplicate and abstract import items; Functor/Applicative/MonadFail instances; `f.g` -> `f . g`; `(<>)` hidden; pre-addendum `foreign import`; unboxed literals; `f :: T = e` split; array indexing and pointer casts through `GhcCompat` |
| Portable serialisation | 0004, 0018 | `Binary.hs` without `ByteArray#`; float bit-casts |
| MicroHs runtime semantics | 0006, 0025, 0026 | the `mk_supply#` CAF (mhs memoises `unsafeInterleaveIO`); strict `!FastInt` in `SrcLoc` (a lazy `Int` under the shims); arithmetic that must wrap, `hFileSize`, `exitWith` (D47's gaps) |
| Build plumbing | 0003, 0023, 0024 | `MachDeps.h` include path; a `#error GHC >= 5.00` guard; non-GHCi stubs in `TcSplice` |
| Bootstrapping proper | 0001 | `unlit` and a trailing space, again |

Again one patch in the series is about bootstrapping.

**Nothing about x86-64.** The two RTS patches (58 cast-as-lvalue sites, one
`static`/`extern` mismatch) live in `ghc622/rts/patches` and are the "C
that stopped being legal" class, not the 64-bit class; configure accepted
the triple unaided (`build/rts622/FINDINGS.md`). The 4.08.2 series had 18
defects in `Int.lhs`/`Word.lhs` alone under `WORD_SIZE_IN_BYTES == 8`.
Here the 64-bit problems that surfaced were in the toolchain, not the
source: `-fwrapv` and `-std=gnu89` on every `.hc` compile (D48), and the
`HTYPE_*` block that gcc 16 stops configure from producing (D47).

**One edit came late.** `main/GetImports.hs` reads source through a text
handle, which under the MicroHs runtime decodes UTF-8 and dies on
`Ctype.lhs`. The `__MHS__` branch was made during stage 2 (D49,
`notes/phase4/FINDINGS.md` section 8) and is now the last hunk of
`0026-runtime-wraps-and-driver-exit.patch`.
