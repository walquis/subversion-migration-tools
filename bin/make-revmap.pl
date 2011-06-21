#!/site/apps/perl/bin/perl
my $offset = $ARGV[0] ? $ARGV[0] : 0;
while (my $l = <STDIN>) {
	my($r,$s) = $l =~ m/Renumbered revision (\d+) to (\d+)/;
	next unless $r;
	print sprintf("%d,%d\n", $r, $s + $offset);
}
