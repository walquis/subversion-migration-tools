#!/site/apps/perl/bin/perl
#
# 89803754d89803753
#< Content-length: 0
#
# Print the range of lines around line 89_803_754
$line = 89_803_754;
#$line = 300;
$rng = 20;
my $startline = ($ARGV[0] || $line-$rng);
my $endline = ($ARGV[1] || $line+$rng);

while ( <STDIN> ) {
	if ( ($. == $startline) .. ($. == $endline) ) {
		print;
	} elsif ($. > $endline) {
	  last;
	}
}
