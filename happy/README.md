# happy 1.19.5

The parser generator that regenerates GHC 6.2.2's parsers, compiled by
[mhs](../mhs/README.md). Later GHCs build their own happy (1.16, 1.19.5 again,
1.19.12, 1.20.1.1), and each of those starts from this one.

```sh
nix-build -A happy
```

## The seed, and how I got rid of it

happy's own parsers (`Parser.hs`, `AttrGrammarParser.hs`) are happy output, so
one generation has to be an input. `happy-seed/` holds generation 2 of
`build/fixpoint-happy.sh`, and the check phase fails unless the happy built
from it regenerates both files byte for byte.

Generation 1 came from a happy built by my machine's GHC 9.14, used once as a
generator. Generation 3 is byte-identical to generation 2, so that GHC-built
happy is out of the trusted base ([D7](../DECISIONS.md#d7--use-the-machines-ghc-9141-as-a-one-time-generator-then-discharge-it), [D14](../DECISIONS.md#d14--verify-happy-by-generation-not-by-equality-with-happy-ghc)).

A fixed point only shows that the seed reproduces itself, so I also check it
by diverse double compilation, from a seed that has nothing to do with mine
([D56](../DECISIONS.md#d56--happys-seed-by-diverse-double-compilation-from-happy-115)):

```sh
nix-build -A happy.ddc115
```

happy's repository commits, at the `Happy_1_15` tag, the `Parser.hs` that
happy 1.14 wrote. mhs builds happy 1.15 from it, with Alexandre Tunstall's
patch from [#2](https://github.com/andreabedini/ghc-bootstrap/issues/2). That
happy generates 1.19.5's two parsers, mhs builds 1.19.5 from them, and the
check phase fails unless that 1.19.5 regenerates `happy-seed/` byte for byte.
It does. The check is its own derivation, so happy's derivation, and the
chain after it, do not change.

Comparing with the GHC-built happy directly would have been the wrong test:
that one was a 1.19.12, and its output differs from 1.19.5's anyway (the
`happyExpList` feature).

## Files

| File | What it is |
|---|---|
| `default.nix` | happy, with the diverse double compilation check as `happy.ddc115` |
| `happy.nix` | the derivation: happy 1.19.5 from Hackage, compiled by mhs with the shims in `common/shims` |
| `ddc115.nix` | the check: happy 1.15 from the `Happy_1_15` tag, then 1.19.5 from its output, against `happy-seed/` |
| `ddc115/happy-1.15-mhs.patch`, `ddc115/Paths_happy.hs` | what happy 1.15 needs under mhs: the source part of the patch on issue #2, and what Cabal would generate |
| `happy-seed/Parser.hs`, `happy-seed/AttrGrammarParser.hs` | the seed: generation 2 of happy's own parsers |
| `noglr/ProduceGLRCode.hs` | a stand-in for the GLR backend, which does not compile under mhs and which nothing in the chain uses. Same interface; its one entry point refuses at run time |
| `shim/Paths_happy.hs` | what Cabal would generate |

The template is `cpphs --noline templates/GenericTemplate.hs`.
[`notes/phase1/happy.md`](../notes/phase1/happy.md) has the analysis of happy under mhs.
