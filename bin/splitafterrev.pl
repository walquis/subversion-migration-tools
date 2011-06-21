#!/site/apps/perl/bin/perl

# Given a revision <R> as first arg, <prefix> as optional 2nd arg,
# and a dumpfile as stdin, get the revision as follows:
#
# Create a file "<prefix>after-<R>.dump"

print "**************************\nWARNING:  This script should be rewritten to use SVN::Dump !!!\n******************************\n";

die "USAGE: $0 rev-to-splitafter [file-prefix] < aDumpFile\n" if $#ARGV < 0;

my $rev = 0;
my $rev_to_split = $ARGV[0];
my $prefix ||= $ARGV[1];
my $header;

my @header = <DATA>;

open(BEFORE, ">${prefix}upthru-${rev_to_split}.dump");
my $fh = *BEFORE;

my $prev_mode= -1;
my $mode = 0;
my $reading_header;

while (my $line = <STDIN>) {
	# Strip off the header, if detected.
	if (/SVN-fs-dump-format-version:/) {
		$reading_header = 1;
		$. = 1;
	}
	if ($reading_header) {
		$reading_header = 0 if $. >= 4;
		next;
	}


	if ($line =~ /^Revision-number: (\d+)/) {
		$rev = $1;

		if ($rev <= $rev_to_split) {
			$mode = 0;
		} elsif ($rev >  $rev_to_split) {
			$mode = 2;
			if ($mode != $prev_mode) {
				close BEFORE;
				open(AFTER, ">${prefix}after-${rev_to_split}.dump");
				$fh = *AFTER;
			}
		}

		if ($mode != $prev_mode) {
			print $fh @header;
			$prev_mode = $mode;
		}
	}

	print $fh $line;
}
close AFTER;

__END__
SVN-fs-dump-format-version: 2

UUID: e69698d3-d34e-4e6d-b957-e9daec51f3fd

