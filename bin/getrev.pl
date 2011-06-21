#!/site/apps/perl/bin/perl
# Given a revision <R> as first arg, and a dumpfile <someName.dump> as 2nd arg,
# get the revision as follows:
#
# Create a file "<someName>.<R>.dump"
#
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use SVN::Dump 0.04;

my $debug = 1;
die "USAGE: $0 rev-to-split aDumpFile\n" if $#ARGV < 1;

my $rev_to_split = $ARGV[0];
my $inputfile = $ARGV[1];

die "input file must be suffixed with '.dump'" unless $inputfile =~ /\.dump$/;

my $prefix = ($inputfile =~ /(.*)\.dump$/)[0];

open(our $outfh, ">${prefix}.${rev_to_split}.dump");

our @header = <DATA>;
our $dump = SVN::Dump->new( { file => $inputfile } );
our $curr_rev = 0;
our $revs_seen = 0;

eval {
	while (my $r = $dump->next_record ) {
		if ( is_revision($r) ) {
			$curr_rev = $r->get_header("Revision-number");
			$revs_seen++;
			print STDERR "Processed $revs_seen revisions; revision number = $curr_rev\n" if $debug && ! $revs_seen % 1000 ;
			if ( $curr_rev == $rev_to_split ) {
				print_entire_revision($r, $dump, $outfh);
				last;
			}
		}
	}
} or do {
	if ($@) {
		print "Problem retrieving data, last recorded revision was $curr_rev...\n";
		print $@;
		exit;
	}
};

exit $?;


sub is_revision {
	my $r = shift;
  return 1 if $r->type() eq 'revision';
  warn "Couldn't determine type of a record in revision $curr_rev" if $r->type() eq 'unknown';
  0;
}


sub print_entire_revision {
	my($revision_record,$dump,$fh) = @_;

	print $fh @header;

	print $fh $revision_record->as_string();
	my $r;
	while ( ($r = $dump->next_record) && ! is_revision($r) ) {
		print $fh $r->as_string();
	}
}

__END__
SVN-fs-dump-format-version: 2

UUID: e69698d3-d34e-4e6d-b957-e9daec51f3fd

