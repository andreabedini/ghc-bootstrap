# GHC 6.2.2 parser/Lexer.hs and StringBuffer under mhs

Result: `build/lexer622/Lexer.hs` compiles with mhs (`sh notes/probes/lexer622-compile.sh Lexer`,
rc=0, ~80 s cold / ~25 s warm), and a token-dump driver built from it lexes a
sample program, a 79-file corpus and the cpp-stripped Lexer.hs itself with the
expected tokens and spans. READY is touched.

## Deliverables

| file | what |
|---|---|
| `Lexer.hs` (1373 lines) | 6.2.2's shipped `alex -g` output, hand-converted; generated from the pristine file by `convert-lexer.py` (now `ghc622/tools/convert-lexer.py`) |
| `convert-lexer.py` | the conversion, every edit asserted against the pristine text (re-runnable); now `ghc622/tools/convert-lexer.py` |
| `StringBuffer.hs` (118 lines) | new shim for the 6.2.2 StringBuffer API (11 functions); now `ghc622/shims/StringBuffer.hs` |
| `overlay/SrcLoc.lhs` | one dependency fix (strict line/column fields), see "Overlay"; now the SRCLOC hunk of `ghc622/patches` |
| `compile.sh` | the mhs invocation (INC/HSCPP recipe of probe-ordered-slit.sh, own `-C` cache in `work/`) |
| `includes/` | pristine 6.2.2 `ghc/includes/*.h` + form-feed-free `config.h` from rts622 + generated `DerivedConstants.h` |
| `utils/ghc-pkg/Package.hs` | pristine copy (no longer kept: the tarball's), needed via `#include "../utils/ghc-pkg/Package.hs"` (see "Tree layout") |
| `driver/Main.hs` | token-dump driver (`work/lexdump`), verification only |

Directory search order used: `build/lexer622` (Lexer.hs, StringBuffer.hs), `shims/` (empty),
`overlay/`, `notes/phase2/hsboot-6.0-run2`, `build/shims-6.0-run2`, `common/shims{,-ghc,-h98}`,
`notes/phase2/gen-6.0`, then every subdirectory of `build/rebase622/try622`.

## Approach: (1) hand-convert the shipped -g output

Chosen over (2) writing the basic template's list driver because the user code
(lines 56-1093, everything from Lexer.x) contains no unboxed syntax at all --
the only `#`s outside the template are inside string literals -- so the whole
problem is the four table literals and ~60 lines of template runtime. The
converted file is identical to the shipped one except for the edits listed
below; the DFA and its actions are untouched.

### Table encoding

This alex 2.0 `-g` template stores every table as an `Addr#` byte string of
**16-bit little-endian signed** entries and has *no* `WORDS_BIGENDIAN` branch
(the byte order is fixed in the reader, not in the emitted data):

```
alexIndexShortOffAddr (AlexA# arr) off = narrow16Int# i
  where i    = word2Int# ((high `uncheckedShiftL#` 8#) `or#` low)
        high = int2Word# (ord# (indexCharOffAddr# arr (off*2 + 1)))
        low  = int2Word# (ord# (indexCharOffAddr# arr (off*2)))
```

The four literals are all-`\xHH` strings: `alex_base` and `alex_deflt` 630
bytes (315 entries = states 0..314, matching `alex_accept = listArray (0,314)`),
`alex_table` and `alex_check` 21424 bytes (10712 entries). The conversion keeps
the very same string literals and decodes them once at startup:

```haskell
newtype AlexAddr = AlexA (Array Int Int)
alexA s = AlexA (listArray (0, n - 1) (decode s))          -- n = length s `div` 2
  where decode (lo : hi : rest) = entry (ord lo + ord hi * 256) : decode rest
        entry v | v >= 32768 = v - 65536 | otherwise = v   -- narrow16Int#
alexIndexShortOffAddr (AlexA arr) off = arr ! off
```

so the `\xff\xff` sentinels come out as -1, which `alex_scan_tkn` tests for.
There are no 32-bit entries in this template version.

### Every deviation from the shipped Lexer.hs

1. Lines 37-41: the `#if >= 503 import GHC.Exts #else import GlaExts #endif`
   block is removed (nothing unboxed remains). `Array`, `Char (ord)`,
   `DATA_BITS`, `TRACE` etc. are unchanged and resolve through HsVersions.h to
   the h98 shims because we compile with `__GLASGOW_HASKELL__=408`.
2. Lines 43/46/49/52: `AlexA# "..."#` -> `alexA "..."`, same literal.
3. Lines 56-59: the Alex-2.0 workaround `unsafeAt arr i = arr ! i` (active
   for GHC < 503) is dropped: MicroHs's `Data.Array` (`Mhs.Array`) already
   exports `unsafeAt`, and a local definition made every use ambiguous.
4. Lines 204-206: `#ifdef DEBUG deriving Show` becomes
   `#if defined(DEBUG) || defined(LEXER_SHOW_TOKENS)`. Only the driver build
   defines `LEXER_SHOW_TOKENS`; the tree build is unaffected.
5. Lines 874-877: `instance Monad P` (with `fail = failP`) becomes
   `Functor`/`Applicative`/`Monad`/`MonadFail P` instances over `returnP`/`thenP`;
   `fail = failP` moves to `MonadFail` (the do-blocks bind `tok@(T _ _ _)` and
   `inp@(loc1,buf)`, which mhs treats as failable).
6. Lines 1208-1352 (the template runtime): `AlexAddr`/`alexA`/
   `alexIndexShortOffAddr` as above; `alexScan`/`alexScanUser` take a boxed
   start code; `alex_scan_tkn`'s `case s of -1# ->` becomes `if s == -1`, and
   `len` is `seq`'d each step (an `Int#` accumulator was strict for free);
   `alex_scan_tkn'` uses `+`/`==`/`>=` and `alex_accept `unsafeAt` s`;
   `alexRightContext` takes a boxed sc; `iUnbox (I# i) = i` ("used by
   wrappers") is dropped -- Lexer.x has no wrapper and `FastTypes` (imported
   whole) exports an `iUnbox`.
   One new guard: `offset < alex_check_size` next to `offset >= 0`. With
   `Addr#` an out-of-range read of `alex_check` returned garbage that could not
   match; a boxed array would raise. It only matters for a `Char` above the
   DFA's alphabet and never fired in the tests.
7. The `{-# LINE n "parser/Lexer.x" #-}` / `"GenericTemplate.hs"` pragmas are
   kept; mhs honours them, so its error messages for this file are in Lexer.x
   / GenericTemplate.hs coordinates (seen in the negative test below).

Nothing else changed; `alex_accept` compiles without a type signature.

## StringBuffer.hs shim

Verified the API by `rg` over the 6.2.2 compiler: the only users are Lexer.x
(currentChar, prevChar, lookAhead, atEnd, stepOn, stepOnBy, lexemeToString,
lexemeToFastString), HscMain (hGetStringBuffer, stringToStringBuffer),
RnHiFiles and ParsePkgConf (hGetStringBuffer); `difference` is exported but
unused. Types match `utils/StringBuffer.lhs` exactly (`prevChar :: SB -> Char
-> Char`, `stepOnBy :: Int -> SB -> SB`, the `(buf, len)` lexeme forms).

Representation: `StringBuffer !(Array Int Char) !Int !Int` (contents, length,
cursor) -- O(1) indexing and O(1) step, as the ByteArray# original. Semantics
copied function by function, with these documented differences:

- The buffer holds *bytes*: `hGetStringBuffer` reads with
  `Data.ByteString.readFile` (the original used `openBinaryFile`) and
  `stringToStringBuffer` truncates each `Char` mod 256 (the original did
  `fromIntegral . ord :: Word8`). So every `Char` handed to the lexer is in
  0..255, which the alex tables assume.
- `currentChar`/`lookAhead` return `'\NUL'` out of range instead of the
  original's ASSERT/garbage read.
- No NUL sentinel (6.2.2 dropped it; the lexer tests `atEnd`).
- `lexemeToFastString` goes through `lexemeToString` and `mkFastString` from
  the shim FastString (not `mkFastSubStringBA#`).

## Verification

1. `sh notes/probes/lexer622-compile.sh Lexer` -> rc=0 (only the pre-existing cpphs
   warning about `FiniteMap.lhs:35`). A negative test -- a copy of Lexer.hs
   with an appended type error placed first on the -i path -- fails with the
   error located in `GenericTemplate.hs`, proving it is this Lexer.hs that
   mhs compiles and not try622's.
2. Token-dump driver: `DEFS=-DLEXER_SHOW_TOKENS PREINC=$PWD/driver
   OUT=$PWD/work/lexdump sh compile.sh Main` links a 620 KB executable.
   `./work/lexdump [file]` runs `lexer` through the P monad from
   `mkPState buf (mkSrcLoc name 1 0) (defaultDynFlags + GlasgowExts + FFI)`,
   as HscMain does, and prints `line:col-line:col  token` per token.
   - Built-in sample (module header, qualified import, line and nested block
     comments, guards, `0x1F`/`0o17`/`3.25e-2`, string with `\n \" \SOH`
     escapes, `where`/`let` layout, `{-# INLINE #-}`, `+# ==# 1# 2.0##`,
     record/strict field, `foreign import ccall unsafe`, explicit braces):
     every token is the expected constructor with the expected span
     (`ITvocurly`/`ITsemi`/`ITvccurly` at the right columns, `ITinline_prag`
     via the `notFollowedBy '#'` predicate, `ITqvarid (M,baz)`,
     `ITinteger 31`, `ITrational (13 % 400)`, `ITprimdouble (2 % 1)`, ...).
   - 79 cpp-free MicroHs library modules (`lib/Data`, `lib/Control`,
     `lib/Text`): 0 lexical errors.
   - The pristine Lexer.hs itself: stops with `parser/Lexer.x:30: lexical
     error` -- correct: line 2's `{-# LINE 23 "parser/Lexer.x" #-}` was
     honoured (line 10 = 23+7) and a `#include` at beginning-of-line enters
     `line_prag1`, which is what GHC 6.2.2 does on un-cpp'd input. With the
     `#` lines stripped it lexes to `ITeof` (8913 tokens), including the 85 KB
     `"\x00..."` literals as `ITprimstring`, tabs, and the `'`-suffixed names.
   - Error paths: `'ab'` -> `lexical error in string/character literal` at the
     right position; `0xZZ` -> `ITinteger 0`, `ITvarid xZZ` (maximal munch).
3. Long single-line tokens (90K-char identifier / string / escaped string)
   overflowed the mhs stack *before* the overlay below; comments of the same
   length did not. Root cause and fix under "Overlay". After it all pass.

## Overlay (dependency fix for the tree agent)

`overlay/SrcLoc.lhs` = try622's `basicTypes/SrcLoc.lhs` with the `SrcLoc`
constructor's line and column made strict:

```
  | SrcLoc	FastString	-- A precise location (file name)
		!FastInt	-- line
		!FastInt	-- column
		-- mhs: FastInt is a boxed Int here, not Int#, so without the bangs ...
```

Why: `advanceSrcLoc (SrcLoc f l c) _ = SrcLoc f l (c +# 1#)` is strict in GHC
because `FastInt` is `Int#`; under the FastTypes/GlaExts shims it is a lazy
`Int`, so `alexGetChar`'s `loc' `seq`` only forces the constructor and one
`(+1)` thunk per character accumulates in the column until something forces
it (a token's end column, `getOffside`, an error message). A newline resets
it, so only lines beyond ~50K columns overflow the default 250K-slot stack.
The 6.0 tree has the same declaration and the same exposure. Not a Lexer or
StringBuffer bug, but the lexer is where it shows, so it is worth folding into
the tree (it also removes a per-character thunk from the hot loop).

## Tree layout notes (not code fixes, but needed to compile Lexer's deps)

- `main/Constants.lhs` does `#include "../includes/DerivedConstants.h"`; the
  file is generated. `gcc -O2 -w -include stdio.h -I<includes>
  -Wl,--unresolved-symbols=ignore-all ghc/includes/mkDerivedConstants.c`
  builds it on modern gcc (missing `<stdio.h>`, and `Stg.h` drags in
  never-called gmp/stable-ptr inlines that do not link). The 6.2.2 output is
  byte-identical to `build/ghc-6.0-run2/ghc/includes/DerivedConstants.h`.
- `main/Packages.lhs` does `#include "../utils/ghc-pkg/Package.hs"`; with
  try622 being a bare compiler dir the relative path only resolves against an
  `-I` dir, hence `build/lexer622/utils/ghc-pkg/Package.hs` next to
  `includes/`. The file is the pristine 6.2.2 one (unedited in the 6.0 run
  and in ghc-6.2.2-run1). `rebase622/ghc-6.2.2` has no `ghc/utils`; it was
  taken from `build/rts622`.

## Reproducing

```sh
cd build/lexer622
python3 convert-lexer.py ../rebase622/ghc-6.2.2/ghc/compiler/parser/Lexer.hs Lexer.hs
sh compile.sh Lexer                                   # rc=0
DEFS=-DLEXER_SHOW_TOKENS PREINC=$PWD/driver OUT=$PWD/work/lexdump sh compile.sh Main
./work/lexdump                                        # built-in sample
./work/lexdump some/File.hs
```
