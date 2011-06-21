package SVN::DumpTools::RevisionMap;
use lib '/home/buildadmin/site_perl/lib';
use strict;
use warnings;
use SVN::Dump 0.04;


sub renumber_mergeinfos {
	my($r, $revision_offset, $rev_map) = @_;
	if ($r->get_property_block() ) {
		if (my $mi_prop = $r->get_property('svn:mergeinfo') ) {
			$r->set_property('svn:mergeinfo', renumber_mergeinfo_property($mi_prop, $revision_offset, $rev_map));
		}
	}
}


sub renumber_mergeinfo_property {
	my($prop,$revision_offset,$rev_map) = @_;
	my @mapped_prop_lines;
	foreach my $line (split("\n",$prop)) {
		my($path,$rev_list) = ($line =~ m!(.*):(.*)!) ;
		my @mapped_rev_list;
		foreach my $rev_range( split(",",$rev_list)) {
			# Could be a single rev or a range...
			my $mapped_rev_range;
			if ($rev_range =~ /-/) {
				my($from_rev,$to_rev) = split("-",$rev_range);
				my $mapped_from_rev = rev_at_or_before($from_rev,$rev_map) + $revision_offset;
				my $mapped_to_rev   = rev_at_or_before($to_rev  ,$rev_map) + $revision_offset;
				$mapped_rev_range = ($mapped_from_rev eq $mapped_to_rev) ? $mapped_from_rev : "$mapped_from_rev-$mapped_to_rev";
			} else {
				$mapped_rev_range = rev_at_or_before($rev_range,$rev_map) + $revision_offset;
			}
			push(@mapped_rev_list,$mapped_rev_range);
		}
		push(@mapped_prop_lines, "$path:" . join(",", @mapped_rev_list));
	}
	join("\n", @mapped_prop_lines);
}


# Return the destination revision in the map before the legacy $rev.
sub rev_at_or_before {
  my($legacy_rev, $rev_map) = @_;
  my @old_revs = sort { $a <=> $b } keys %$rev_map;
  for ( my $i=$#old_revs; $i>=0; $i--) {
		return $rev_map->{$old_revs[$i]} if $old_revs[$i] <= $legacy_rev ;
  }
	# Bail out with one less than the oldest mapped revision.
	my $oldest_mapped_revision = $rev_map->{$old_revs[0]};
	return $oldest_mapped_revision > 0 ? $oldest_mapped_revision-1 : 0;
}

1;
