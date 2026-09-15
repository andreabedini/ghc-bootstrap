#!/usr/bin/perl
# Post-process an interface file the way GHC 4.08.2's driver did.
#
# hsc writes only a partial .hi: no module-version integer in the header, no
# per-declaration version numbers, and the sections in the order MkIface emits
# them rather than the order ParseIface.y requires. MkIface.lhs says as much:
#
#   NOTE: ALWAYS remember that ghc-iface.lprl rewrites the interface file,
#   so you have to keep it in synch with the code below.
#
# So rather than reimplement that logic and risk diverging from it, this loads
# GHC's own ghc-iface.prl (unlit from the shipped ghc-iface.lprl) and calls its
# constructNewHiFile, supplying the handful of driver globals it reads.
#
#   phase3/hi-postprocess.pl <hsc-output.hi> <final.hi> <ModuleName>
use strict 'subs';

my ($hsc_hi, $target, $modname) = @ARGV;
die "usage: hi-postprocess.pl <in.hi> <out.hi> <Module>\n" unless $modname;

# Driver globals that constructNewHiFile reads. The version bookkeeping exists
# to avoid recompilation; a from-scratch build has no previous interface, so the
# "old" side is simply absent.
# NB: ghc-iface.prl initialises these at its own top level, and `require`
# runs that, so the globals must be set *after* it is loaded or they are
# silently reset (%HiExists back to -1, and the module version comes out
# empty).
require "$ENV{GHC_IFACE_PRL}" or die "cannot load ghc-iface.prl: $!\n";

$ProjectVersionInt = 408;
$HiSuffix          = 'hi';
$Specific_hi_file  = '';
$Verbose           = 0;
$HiDiff_flag       = 0;
$HiOnStdout        = 0;
$Tmp_prefix        = "/tmp/hipp$$";
$Cat = 'cat'; $Cmp = 'cmp'; $Diff = 'diff'; $Rm = 'rm -f'; $Mv = 'mv';
# 0 means 'definitely does not exist', which is the truth for a from-scratch
# build and makes calcNewModuleVersion return 1 ('no old .hi file').
%HiExists      = ('old',  0, 'new', -1);
%HiHasBeenRead = ('old',  0, 'new',  0);
%ModuleVersion = ('old',  0, 'new', 0);
%PackageName   = ('old', '', 'new', '');
%ModuleName    = ('old', '', 'new', $modname);
%Orphan        = ('old', '', 'new', '');
%OldVersion = (); %Decl = (); %Stuff = (); %HiSections = ();


# constructNewHiFile treats $hifile_target as a possibly-existing *previous*
# interface and reads it to compute version deltas. In a from-scratch build
# there is no previous one, and if a stale file is sitting at that path the
# module version comes out empty. So point it at a path that cannot exist, and
# state the fact directly.
my $scratch = "$target.prev$$";
unlink $scratch;
$HiExists{'old'} = 0;

my $new = "$target.new$$";
&constructNewHiFile($hsc_hi, *scratch, $new, 0);
rename($new, $target) or die "rename: $!\n";
unlink $scratch;
