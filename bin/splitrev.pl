#!/site/apps/perl/bin/perl

# Given a revision <R> as first arg, and a dumpfile <someName.dump> as 2nd arg,
# split the dumpfile as follows:
#
# Create a file "<someName>.before-<R>.dump"
# Create a file "<someName>.<R>.dump"
# Create a file "<someName>.after-<R>.dump"
#
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use SVN::Dump 0.04;

die "USAGE: $0 rev-to-split aDumpFile\n" if $#ARGV < 1;

my $curr_rev = 0;
my $rev_to_split = $ARGV[0];
my $inputfile = $ARGV[1];

die "input file must be suffixed with '.dump'" unless $inputfile =~ /\.dump$/;

my $prefix = ($inputfile =~ /(.*)\.dump$/)[0];

my @header = <DATA>;

open(BEFORE, ">${prefix}.before-${rev_to_split}.dump");
my $fh = *BEFORE;

my $prev_mode= -1;
my $mode = 0;

our $dump = SVN::Dump->new( { file => $inputfile } );

while (my $r = $dump->next_record) {
	next if $r->type() eq 'uuid';	   # Skip a repo header.
	next if $r->type() eq 'format';	 # Skip a repo header.

	if ( is_revision($r) ) {
		$curr_rev = $r->get_header("Revision-number");

		if ($curr_rev < $rev_to_split) {
			$mode = 0;
		} elsif ($curr_rev == $rev_to_split) {
			$mode = 1;
			if ($mode != $prev_mode) {
				close BEFORE;
				open(REV, ">${prefix}.${rev_to_split}.dump");
				$fh = *REV;
			}
		} elsif ($curr_rev >  $rev_to_split) {
			$mode = 2;
			if ($mode != $prev_mode) {
				close REV;
				open(AFTER, ">${prefix}.after-${rev_to_split}.dump");
				$fh = *AFTER;
			}
		}
		if ($mode != $prev_mode) {
			print $fh @header;
			$prev_mode = $mode;
		}
	}
	print $fh $r->as_string();
}
close AFTER;

sub is_revision {
	my $r = shift;
	return 1 if $r->type() eq 'revision';
	warn "Couldn't determine type of a record in revision $curr_rev" if $r->type() eq 'unknown';
	0;
}

__END__
SVN-fs-dump-format-version: 2

UUID: e69698d3-d34e-4e6d-b957-e9daec51f3fd

