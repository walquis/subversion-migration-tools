#!/site/apps/perl/bin/perl

# Given a dumpfile stream on STDIN, renumber its revisions and print the renumbered stream to STDOUT.

use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use SVN::Dump 0.04;
use SVN::DumpTools::RevisionMap;
use Getopt::Long;

my $revmap_offset;
my $revmap_infile;
my $rev_offset = 0;
GetOptions(
  'revmap_offset=s' => \$revmap_offset,
	'revmap_infile=s' => \$revmap_infile,
	'rev_offset=s' => \$rev_offset,
);
my $curr_rev = $rev_offset;

defined($revmap_offset) or die <<"EOF";
Please specify '--revmap_offset <offset>', for the benefit of renumbering svn:mergeinfo properties.
(This is because 'svnadmin load' was not taught to map mergeinfo properties, at least as of 1.6.12,
although it does handle copyfrom revs).

For instance, if you will be loading into a repo that is already up to revision 3, but the revmap
starts mapping to revision 1, say '--revmap_offset 3'.

If the revmap is already mapping to correct revisions, say '--revmap_offset 0'.

EOF
defined($rev_offset) or die <<"EOF2";
Please specify '--rev_offset <offset>', corresponding to the latest revision of the repo into which
the renumbered dumpfile will be loaded.
EOF2

my $debug = 0;
our $old_rev;
our $rev_map = defined($revmap_infile) ? load_revmap($revmap_infile) : {};

print STDOUT <DATA>;	# Print a repo header.

my $dump = SVN::Dump->new( { file => '-' } );
while ( my $r = $dump->next_record() ) {
	next if $r->type() eq 'format';	 # Skip a repo header
	next if $r->type() eq 'uuid';	   # Skip a repo header
	if ($r->type() eq 'revision') {  # Renumber the revision and record it in the map.
		$curr_rev++;
		$old_rev = $r->get_header("Revision-number");
		$rev_map->{$old_rev} = $curr_rev;
		$r->set_header("Revision-number", $curr_rev);
		print STDERR "Renumbered revision $old_rev to $curr_rev\n";
	}
	if ($r->type() eq 'node') {	 # Check for a Node-copyfrom-rev...
		renumber_copyfrom_rev_for($r);
		if (my $included = $r->get_included_record() ) { # Included records may have copyfroms too...
			renumber_copyfrom_rev_for($included);
		}
	}

	SVN::DumpTools::RevisionMap::renumber_mergeinfos($r, $revmap_offset, $rev_map);

	print $r->as_string();
}

write_revmap($rev_map, $rev_offset);

exit $?;
##############################  End of main

sub write_revmap {
	my($revmap, $offset) = @_;

	my @keys = sort { $a <=> $b } keys %$revmap;

	my $revmap_outfile = sprintf( "revmap.%d-%d.csv",$revmap->{$keys[0]}, $revmap->{$keys[-1]} );
	open(F, sprintf( ">$revmap_outfile" ) ) or die "Couldn't open $revmap_outfile for writing";
	foreach my $k (@keys) {
		print F sprintf("%s,%s\n", $k, $revmap->{$k} );
	}
	close F;
}


sub renumber_copyfrom_rev_for {
	my $r = shift;
	if (my $copyfromrev = $r->get_header("Node-copyfrom-rev")) {
		my $newcopyfromrev = SVN::DumpTools::RevisionMap::rev_at_or_before($copyfromrev, $rev_map);  # Set renumbered revision.
		$r->set_header("Node-copyfrom-rev", $newcopyfromrev);  # Set renumbered revision.
		printf STDERR "Original-revision $old_rev: Renumbered Node-copyfrom-rev from $copyfromrev to $newcopyfromrev, Node-copyfrom-path = %s\n", $r->get_header("Node-copyfrom-path");
	}
}

sub load_revmap {
	my $file = shift;
	my $revmap = {};
	open(F, "$file") or die "Couldn't open revmap file '$file' for reading";   
	while (my $l = <F>) {
		chop $l;
		my ($old,$new) = split(/,/, $l);
		$revmap->{$old} = $new;
	}
	close F;
	$revmap;
}

__END__
SVN-fs-dump-format-version: 2

UUID: e69698d3-d34e-4e6d-b957-e9daec51f3fd

