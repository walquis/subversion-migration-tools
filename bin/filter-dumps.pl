#!/site/apps/perl/bin/perl
# Given a dumpfile <someName.dump> as STDIN, filter revisions against paths in filters.txt. 
# Print the accepted revisions on STDOUT.
#
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use SVN::DumpTools::Filter;
use Getopt::Long;

my $filter_file;
GetOptions( 'filter-file=s' => \$filter_file,);
$filter_file ||= 'filters.txt';

open(my $in , '<-');
open(my $out, '>-');
my @filters = read_filters($filter_file); # Get filter specs (could be regexes)

my $filterer = SVN::DumpTools::Filter->new(\@filters, $in, $out);

$filterer->filter_revisions;

exit $?;
# End of main logic.

sub read_filters {
	my $fname = shift;
	open(F,$fname) or die "Couldn't open $fname for reading";
	my @filters = <F>;
	chomp(@filters);
	return @filters;
}
