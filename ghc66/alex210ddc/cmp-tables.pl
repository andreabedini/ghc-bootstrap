# Compares the DFA of two alex -g lexers: the four AlexA# tables
# (alex_base, alex_table, alex_check, alex_deflt) as integers, and
# alex_accept as text. Used on GHC 6.2.2's parser/Lexer.hs, which alex 2.0
# wrote, against alex 2.1.0's output on the same Lexer.x: alex 2.0 packs
# every table in 16-bit words, alex 2.1.0 packs alex_base in 32-bit ones, so
# a table whose byte length doubled is read as 16-bit on the left and 32-bit
# on the right. Usage: perl cmp-tables.pl <old.hs> <new.hs>
use strict;
use warnings;

sub tables {
    my ($file) = @_;
    open my $fh, '<', $file or die "$file: $!";
    my %t;
    while (<$fh>) {
        if (/^(alex_(?:base|table|check|deflt)) = AlexA# "((?:\\x[0-9a-f]{2})*)"#$/) {
            my ($name, $hex) = ($1, $2);
            $hex =~ s/\\x//g;
            $t{$name} = pack 'H*', $hex;
        } elsif (/^(alex_accept) = (.*)$/) {
            $t{$1} = $2;
        }
    }
    die "$file: not five tables\n" unless keys %t == 5;
    return \%t;
}

my ($l, $r) = map { tables($_) } @ARGV;
my $bad = 0;
for my $name (qw(alex_base alex_table alex_check alex_deflt)) {
    my ($a, $b) = ($l->{$name}, $r->{$name});
    my ($wa, $wb) = length $b == 2 * length $a ? ('s<', 'l<') : ('s<', 's<');
    my @a = unpack "$wa*", $a;
    my @b = unpack "$wb*", $b;
    my $same = "@a" eq "@b";
    $bad++ unless $same;
    printf "%s: %d entries, %s%s\n", $name, scalar @a,
        $same ? 'the same' : 'DIFFERENT',
        $wb eq 'l<' ? ' (16-bit words on the left, 32-bit on the right)' : '';
}
my $same = $l->{alex_accept} eq $r->{alex_accept};
$bad++ unless $same;
printf "alex_accept: %s\n", $same ? 'the same' : 'DIFFERENT';
exit($bad ? 1 : 0);
