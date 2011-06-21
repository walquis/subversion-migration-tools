# Given a revision <R> as first arg, and a dumpfile as stdin, get the revision as follows:
#
# Create a file "after-<R>.dump"
#
# If a 2nd arg is given, it is used as a prefix for the above file.

print "WARNING:  This script should be rewritten to use SVN::Dump !!!\n";

die "USAGE: $0 rev-to-split [file-prefix] < aDumpFile\n" if $#ARGV < 0;

my $current_rev = 0;
my $rev_to_split = $ARGV[0];
my $prefix ||= $ARGV[1];

open(AFTER, ">${prefix}after-${rev_to_split}.dump");

while (my $line = <STDIN>) {
	if ($. < 5) {	# Spit out the header, so that the resulting file is a viable dumpfile.
		print AFTER $line;
		next;
	}

	$current_rev = $1 if $line =~ /^Revision-number: (\d+)/;

	print AFTER $line if $current_rev > $rev_to_split;
}
close AFTER;
