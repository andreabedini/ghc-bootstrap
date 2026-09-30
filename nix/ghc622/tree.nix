# GHC 6.2.2's source tree in the shape the chain compiles: the configured
# tree with the generated files dropped in, the HTYPE block appended inside
# config.h's include guard, and the ghc-pkg link. phase4/reproduce-6.2.2.sh
# steps 6-8. The output is the whole source root ($out/ghc/compiler is what
# mhs compiles, $out/ghc/rts what the RTS build starts from).
{
  runCommand,
  ghc622-configured,
  ghc622-primops,
  ghc622-parsers,
  ghc622-lexer,
  ghc622-htypes,
}:
runCommand "ghc-6.2.2-tree" { } ''
  cp -a ${ghc622-configured} $out
  chmod -R u+w $out
  C=$out/ghc/compiler
  cp ${ghc622-primops}/* $C/prelude/
  cp -r --no-preserve=mode ${ghc622-parsers}/. $C/
  cp ${ghc622-lexer} $C/parser/Lexer.hs

  H=$out/ghc/includes/config.h
  tail -1 $H | grep -q '^#endif'
  { sed '$d' $H; cat ${ghc622-htypes}; printf '\n#endif /* __FPTOOLS_CONFIG_H__ */\n'; } > config.h
  mv config.h $H
  grep -q '^#define HTYPE_INT ' $H

  ln -s ../../utils/ghc-pkg $C/utils/ghc-pkg
''
