#!/site/apps/perl/bin/perl
# Given a dumpfile <someName.dump> as STDIN, drop empty revisions. 
# Print the non-empty revisions on STDOUT.
#
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use SVN::Dump 0.04;
use File::Temp;
use File::Temp qw/ :seekable /;

die "USAGE: $0 drop-empty-revs.pl < aDumpFile > outDumpFile\n" if $#ARGV > 0;

# init output stream...
our @header = <DATA>;
open(our $outfh, ">-");
print $outfh @header;

our $dump = SVN::Dump->new( { file => '-' } );
our $curr_rev_num = 0;

our $next_record = $dump->next_record;

while (my $rev = next_revision($dump) ) {
	unless ( $rev->{'size'} ) {
		print STDERR "Dropped empty revision $curr_rev_num\n";
		next;
	}
	print_revision($rev);
}

exit $?;
# End of main logic.


sub next_revision {
	my $dump = shift;
	my %rev;

	while ( ! is_revision($next_record) ) {
		return undef unless $next_record;
		$next_record = $dump->next_record;
		print STDERR "Skipped non-revision record, current revision = $curr_rev_num...\n";
	};
		
	$rev{'fh'} = File::Temp->new(UNLINK=>1);
	$curr_rev_num = $next_record->get_header("Revision-number");
	$rev{'size'} = read_revision($next_record, $dump, $rev{'fh'} );

	return \%rev;
}


sub is_revision {
	my $r = shift;
	return 0 unless $r;
  return 1 if $r->type() eq 'revision';
  warn "Couldn't determine type of a record in revision $curr_rev_num" if $r->type() eq 'unknown';
  0;
}


# Reads a revision into a temporary file (for memory conservation when reading large revisions).
sub read_revision {
	my($revision_record,$dump,$fh) = @_;
	my $size = 0;	# Size doesn't count the revision record.

	print $fh $revision_record->as_string();
	while ( ($next_record = $dump->next_record) && ! is_revision($next_record) ) {
		$size++;
		print $fh $next_record->as_string();
	}
	return $size;
}


sub print_revision {
	my $rev = shift;
	my $fh = $rev->{'fh'};
	$fh->seek( 0, SEEK_SET );
	while ( <$fh> ) {
		print $outfh $_ or last;
	}
	die "Problem copying revision to output!\n" if $!;
}

__END__
SVN-fs-dump-format-version: 2

UUID: e69698d3-d34e-4e6d-b957-e9daec51f3fd

