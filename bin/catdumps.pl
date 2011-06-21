#!/site/apps/perl/bin/perl

# Given an argument list of valid dumpfiles, cat them together into another valid dumpfile stream to STDOUT.
# Basically, this means prepending a header, and stripping the repo headers from the dumpfile .

use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use SVN::Dump 0.04;

my $debug = 0;

print STDOUT <DATA>;	# Print the repo headers.

checkFileExistence(@ARGV) or die;

while (my $fname = shift(@ARGV) ) {
	my $dump = SVN::Dump->new( { file => $fname } );
	while ( my $r = $dump->next_record() ) {
		next if $r->type() eq 'format';	 # Skip a repo header
		next if $r->type() eq 'uuid';	   # Skip a repo header
		print $r->as_string();
		if ($debug and $r->type() eq 'revision') {
			printf STDERR "Cat'd revision %s\n", $r->get_header("Revision-number") ;
		}
	}
}

sub checkFileExistence {
	my $success = 1;
	foreach my $f (@_) {
		unless (-e $f) {
			print STDERR "$f: not found\n";
			$success = 0;
		}
	}
	$success;
}

__END__
SVN-fs-dump-format-version: 2

UUID: e69698d3-d34e-4e6d-b957-e9daec51f3fd

