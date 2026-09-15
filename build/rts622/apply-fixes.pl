#!/usr/bin/perl
# Rewrite gcc's cast-as-lvalue extension at exactly the lines gcc reported,
# using the meaning-preserving spelling  (T)lv OP v  ==>  *(T*)&(lv) OP v
# (see DECISIONS.md D40). Sites come from obj/*.log; nothing else is touched.
use strict; use warnings;
my $R = $ENV{GHC_BOOTSTRAP_ROOT} // die "GHC_BOOTSTRAP_ROOT not set: run under mise from the repo (see mise.toml)\n";
my $rts = "$R/build/rts622/ghc-6.2.2/ghc/rts";
my %sites;
for my $log (glob "$R/build/rts622/obj/*.log") {
  open my $fh, '<', $log or die; 
  while (<$fh>) { $sites{$1}{$2} = 1 if m{ghc/rts/([\w.]+):(\d+):\d+: error:}; }
}
my ($changed, $unchanged) = (0, 0);
for my $f (sort keys %sites) {
  my $path = "$rts/$f";
  open my $in, '<', "$path.orig" or die "$path.orig: $!";
  my @lines = <$in>; close $in;
  for my $n (sort { $a <=> $b } keys %{$sites{$f}}) {
    my $l = $lines[$n-1]; my $orig = $l;
    # static/extern conflict (GC.c:84): header StoragePriv.h declares it extern
    $l =~ s/^static (StgClosure\* static_objects;)/$1/;
    # ((StgPtr)p)++  ==>  (*(StgPtr*)&(p))++
    $l =~ s/\(\((\w+)\)(\w+)\)\+\+/(*($1*)&($2))++/;
    # & BCO_LIT(x)  ==>  (W_ *)&literals[x]      (BCO_LIT(n) is (W_)literals[n])
    $l =~ s/&\s*BCO_LIT\((\w+)\)/(W_ *)&literals[$1]/;
    # mid-line form inside a for(;;) header:  , (T)lv += v
    $l =~ s/([;,]\s*)\((\w+)\)\s*(\w+)\s*(\+=|-=)/$1*($2*)&($3) $4/;
    # (T)lv = v, (T)lv += v, (T)lv -= v
    $l =~ s/^(\s*)\(([A-Za-z_]\w*(?:\s*\*+)?)\)\s*(\*?[\w\->.]+)\s*(\+=|-=|=)(?!=)/$1*($2*)&($3) $4/;
    if ($l eq $orig) { warn "UNCHANGED $f:$n: $orig"; $unchanged++ } else { $changed++ }
    $lines[$n-1] = $l;
  }
  open my $out, '>', $path or die; print $out @lines; close $out;
}
print "rewrote $changed sites, $unchanged unchanged\n";
