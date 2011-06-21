#!/site/apps/perl/bin/perl
#
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use SVN::Dump 0.04;

my $files_or_dirs_in_current_rev = 0;
my $size_of_current_rev = 0;
my $curr_rev = 0;

print "Revision\tRev-Size\tFiles-or-Dirs\n";

my $dump = SVN::Dump->new( { file => '-' } );

eval {
	while (my $r = $dump->next_record ) {
		if ( is_revision($r) ) {
			print "$curr_rev\t$size_of_current_rev\t$files_or_dirs_in_current_rev\n";	# Stats from prev revision.
			$curr_rev = $r->get_header("Revision-number");
			$files_or_dirs_in_current_rev = 0;
			$size_of_current_rev = 0;
			next;
		} elsif ( my $size = $r->get_header('Content-length') ) {
			$files_or_dirs_in_current_rev++;
			$size_of_current_rev += $size;
		}
	}
} or do {
	if ($@) {
		print "Problem retrieving data, last recorded revision was $curr_rev...\n";
		print $@;
		exit;
	}
};

print "$curr_rev\t$size_of_current_rev\t$files_or_dirs_in_current_rev\n";

exit $?;

sub is_revision {
	my $r = shift;
  return 1 if $r->type() eq 'revision';
  warn "Couldn't determine type of a record in revision $curr_rev" if $r->type() eq 'unknown';
  0;
}
