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
happy is out of the trusted base ([D7](../DECISIONS.md#d7--use-the-machines-ghc-9141-as-a-one-time-generator-then-discharge-it), [D14](../DECISIONS.md#d14--verify-happy-by-generation-not-by-equality-with-happy-ghc)). This is a fixed point, although
weaker than diverse double compilation.

Comparing with the GHC-built happy directly would have been the wrong test:
that one was a 1.19.12, and its output differs from 1.19.5's anyway (the
`happyExpList` feature).

## Files

| File | What it is |
|---|---|
| `default.nix` | the derivation: happy 1.19.5 from Hackage, compiled by mhs with the shims in `common/shims` |
| `happy-seed/Parser.hs`, `happy-seed/AttrGrammarParser.hs` | the seed: generation 2 of happy's own parsers |
| `noglr/ProduceGLRCode.hs` | a stand-in for the GLR backend, which does not compile under mhs and which nothing in the chain uses. Same interface; its one entry point refuses at run time |
| `shim/Paths_happy.hs` | what Cabal would generate |

The template is `cpphs --noline templates/GenericTemplate.hs`.
[`notes/phase1/happy.md`](../notes/phase1/happy.md) has the analysis of happy under mhs.
