#!/site/apps/perl/bin/perl
# See http://search.cpan.org/~book/SVN-Dump-0.04/lib/SVN/Dump.pm
#
# Find "mergeinfo" properties.
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use SVN::Dump 0.04;
use Getopt::Long;

my $INFO = 1;

################
# Main

my $dump = SVN::Dump->new( { 'file' => '-' } );	 # Read dumpfile from STDIN.

our $curr_rev = 0;
while (my $r = $dump->next_record()) {
	if ( is_revision($r) ) {
		$curr_rev = $r->get_header("Revision-number");
		print STDERR "Revision $curr_rev\n" if ($INFO && !($curr_rev % 1000) );
	}
	if ( my $props = $r->get_property_block() ) {
		if (my $mi = $r->get_property('svn:mergeinfo') ) {
			print "Found a mergeinfo property.  Revision = $curr_rev, value = '$mi'\n";
		}
	}
}

sub is_revision {
	return 1 if $_[0]->type() eq 'revision';
	warn "Couldn't determine type of a record in revision $curr_rev" if $_[0]->type() eq 'unknown';
	0;
}
