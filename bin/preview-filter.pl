#!/site/apps/perl/bin/perl
# See http://search.cpan.org/~book/SVN-Dump-0.04/lib/SVN/Dump.pm

use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use SVN::Dump 0.04;
use Getopt::Long;

my $INFO = 1;
my $filter_file;
GetOptions(
	'filter-file=s' => \$filter_file,
);
$filter_file ||= 'filters.txt';

################
# Main

my $dump = SVN::Dump->new( { 'file' => '-' } );	 # Read dumpfile from STDIN.

open(FILTER,$filter_file) or die "Couldn't open $filter_file for reading";
my @filters = <FILTER>;
chomp(@filters);

our $curr_rev = 0;
while (my $r = $dump->next_record()) {
	if ( is_revision($r) ) {
		$curr_rev = $r->get_header("Revision-number");
		print STDERR "Revision $curr_rev\n" if ($INFO && !($curr_rev % 1000) );
	}
	my $node_path = $r->get_header("Node-path");
	if ( $node_path && included_in_filter($node_path) ) {
		my $copyfrom_path = $r->get_header("Node-copyfrom-path");
		if ( $copyfrom_path &&  ! included_in_filter($copyfrom_path) ) {
			my $copyfrom_rev = $r->get_header("Node-copyfrom-rev");
			print "Warning: '$node_path\@$curr_rev' copies from '$copyfrom_path\@$copyfrom_rev', which is not in the filter list\n";
		}
	}
}

sub included_in_filter {
	my $node_path = shift;
	return 0 unless $node_path;

	foreach my $filter (@filters) {
		return 1 if $node_path =~ m:$filter: ;
	}
	0;
}

sub is_revision {
	return 1 if $_[0]->type() eq 'revision';
	warn "Couldn't determine type of a record in revision $curr_rev" if $_[0]->type() eq 'unknown';
	0;
}
