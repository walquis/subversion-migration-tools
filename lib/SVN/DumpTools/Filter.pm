#!/site/apps/perl/bin/perl
# Given a dumpfile <someName.dump> as STDIN, filter revisions against paths in filters.txt. 
# Modify copyfrompath (but not the copyfromrev) of nodes that point outside the filter. 
# Print to STDOUT all revisions that still have nodes after filtering.
#
package SVN::DumpTools::Filter;
use lib '/home/buildadmin/site_perl/lib';
use strict;
use warnings;
use SVN::Dump 0.04;
use IO::File;
use SVN::DumpTools::PropertySearch;

our $destination_repo = 'http://sup-chisrv03:8078/repos/ti';
our $migration_dir = 'migration-refs';

sub new {
	my $class = shift;
	my $self = {
		filters => shift,	 # ARG1
		infh => shift,	   # ARG2
		outfh => shift,	   # ARG3
		debug => shift,	   # ARG4
		curr_rev_num => 0,
		kept_revisions => {},
		dump => undef,
		next_record => undef,
		filter_directives => {},
	};
	my $ref = bless $self, $class;

	my $infh = $self->infh;
	my $dump = SVN::Dump->new( { fh => $infh } );

	$self->{'dump'} = $dump;
	$self->{'next_record'} = $dump->next_record;

	$self->parse_filters;

	# init output stream...
	my @header = <<HERE;
SVN-fs-dump-format-version: 2

UUID: e69698d3-d34e-4e6d-b957-e9daec51f3fd

HERE

	my $outfh = $self->outfh;
	print $outfh @header;

	$ref;
} # new


# Accessors
sub curr_rev_num      { $_[0]->{'curr_rev_num'}; }
sub debug             { $_[0]->{'debug'}; }
sub dump              { $_[0]->{'dump'}; }
sub filters           { $_[0]->{'filters'}; }
sub filter_directives { $_[0]->{'filter_directives'}; }
sub infh              { $_[0]->{'infh'}; }
sub kept_revisions    { $_[0]->{'kept_revisions'}; }
sub next_record       { $_[0]->{'next_record'}; }
sub outfh             { $_[0]->{'outfh'}; }


# Filters and prints revisions, dropping any that are empty after filtering.
#
sub filter_revisions {
	my $self = shift;
	my $revs_dropped = 0;
	while (my $filtered_rev = $self->next_filtered_revision ) {
		my $revnum = $filtered_rev->{'revision-number'};
		unless ( $filtered_rev->{'node-count'} or defined($self->filter_directives->{'do_not_filter'}->{$revnum}) ) {
			print STDERR ($self->debug ? "Dropped empty revision $revnum\n" : ".");
			$revs_dropped++;
			next;
		}
		$self->print_revision($filtered_rev);
	}
	return $revs_dropped;
}


# Returns the next revision, which may have zero nodes due to filtering.
#
# Creates a revision-referencing hash with these fields:
#		revision-number
#		fh -- Open filehandle to the temporary file with the revision contents
#   node-count
#		original-node-count
#
sub next_filtered_revision {
	my $self = shift;
	my %filtered_rev;

	$self->skip_non_revision_records_if_any;
	return undef unless $self->next_record;
		
	$filtered_rev{'fh'} = IO::File->new_tmpfile;
	$self->{'curr_rev_num'} = $self->next_record->get_header("Revision-number");
 	my $stats = $self->read_revision_with_filtering( $filtered_rev{'fh'} );
	$filtered_rev{'node-count'} = $stats->{'node-count'};
	$filtered_rev{'original-node-count'} = $stats->{'original-node-count'};
	$filtered_rev{'revision-number'} = $self->curr_rev_num;
	$self->kept_revisions->{ $filtered_rev{'revision-number'} }++ if $filtered_rev{'node-count'};

	return \%filtered_rev;
}


# Usually just skips the UUID and FORMAT records.  Warns if any others are skipped (should never happen).
#
sub skip_non_revision_records_if_any {
	my $self = shift;
	while ( ! $self->next_record_is_revision ) {
		return undef unless $self->next_record;
		if ( $self->next_record && $self->next_record->type() !~ /uuid|format/ ) {
			printf STDERR "WARNING: Skipped non-revision record, current revision = %d, type = %s...\n",
			 $self->curr_rev_num, $self->next_record->type();
		}
		$self->{'next_record'} = $self->dump->next_record;
	}
}



# Reads a revision and writes it into a temporary file (for memory conservation when reading large revisions).
# The next record after the end of the revision is saved in $next_record.
sub read_revision_with_filtering {
	my $self = shift;
	my $fh = shift;
	my $count = 0;	# Count doesn't count the revision record.
	my $original_count = 0;	# Count doesn't count the revision record.

	print $fh $self->next_record->as_string();	 # The revision record.
	while ( ($self->{'next_record'} = $self->dump->next_record) && ! $self->next_record_is_revision ) {
		$original_count++;
		unless ($self->filter_node) {
			$count++;
			print $fh $self->next_record->as_string();
		}
	}
	return { 'node-count' => $count, 'original-node-count', $original_count } ;
}


# Apply regex substitution filters sequentially to the node
# Return 1 if the node path matches the filter, 0 if not.
#
sub filter_node {
	my $self = shift;
  my $rec = $self->next_record;
  my $path = $rec->get_header("Node-path");
	my $curr_rev = $self->curr_rev_num;

	my $keep = 0;
	unless ( $self->filter_directives->{'do_not_filter'}->{ $curr_rev } ) {	# Do not filter?
		# Process filters ("include_paths")...
		foreach my $include ( @{$self->filters} ) {
			last if ($path =~ m/^$include/) && $keep++;
		}
		# Process exclude_paths...
		foreach my $hash ( @{ $self->filter_directives->{'exclude_path'} } ) {
			$keep=0, last if $self->should_exclude( "Node-path", $path, $hash ) ;
		}
		unless ($keep) {
			$self->debug and print STDERR sprintf("Filtered from revision %7d: %10d %6s %s\n", $curr_rev, $self->get_size($rec), $rec->get_header("Node-action"), $path);
			if ($rec->get_header("Node-action") eq 'delete') {
				$self->check_for_delete_node_that_is_a_component_of_a_filter($path);
			}
			return 1;
		}
	}
	
	# ASSERTION: Keeping the node. ($keep > 0).
	# Check whether the copyfrom-path will pass the filter...
	$self->filter_copyfrom_path($rec, $curr_rev, $path);

	# Check copyfroms for included record, if any...
	if (my $included_rec = $rec->get_included_record()) {
		$self->filter_copyfrom_path($included_rec, $curr_rev, $path);
	}

  return 0;
}


sub filter_copyfrom_path {
	my($self, $rec, $curr_rev, $path) = @_;
  if ( my $copypath = $rec->get_header("Node-copyfrom-path") ) {
		my $copyrev = $rec->get_header("Node-copyfrom-rev");
		my $copyfrom_ok=0;
		# Process filters ("include_paths")...
		foreach my $include ( @{$self->filters} ) {
			last if ($copypath =~ m/^$include/) && $copyfrom_ok++;
		}
		# Process exclude_paths...
		foreach my $hash ( @{ $self->filter_directives->{'exclude_path'} } ) {
			$copyfrom_ok=0, last if $self->should_exclude( "Node-copyfrom-path", $copypath, $hash ) ;
		}
		unless ($copyfrom_ok) {
			print STDERR sprintf("WARNING: Revision %d, Path %s: Copyfrom-path not included by the filter: Copyfrom-rev = %d, Copyfrom-path = %s\n", $curr_rev, $path, $copyrev, $copypath);
			my $new_copypath = $self->new_copyfrom_path($copypath, $curr_rev, $copyrev);
			print STDERR sprintf("\tChanging Node-copyfrom-path...\n\tfrom: $copypath\n\tto  : $new_copypath\n");
			$rec->set_header("Node-copyfrom-path", $new_copypath);
		}

		# Check whether the copyfrom-rev points to a kept revision...not a big deal if not, since renumber-revs.pl should fix it.
		unless ( defined $self->kept_revisions->{$copyrev} ) {
			$self->debug and printf STDERR "WARNING: Revision %d, Path %s: Copyfrom-rev %d not included by the filter\n", $curr_rev, $path, $copyrev;
		}
	} # if $copypath...
}


sub should_exclude {
	my($self, $node_type, $path, $exclude_path_hash) = @_;
	my $exclude_path = $exclude_path_hash->{'path'};
	my $curr_rev = $self->curr_rev_num;
	if ($path =~ m/^$exclude_path/) {
		if ( defined($exclude_path_hash->{'first_rev'}) ) {
			my $first_rev = $exclude_path_hash->{'first_rev'};
			my $last_rev  = $exclude_path_hash->{'last_rev'};
			if ($curr_rev >= $first_rev and $curr_rev <= $last_rev) {
				print STDERR sprintf("%s: exclude_path pattern '%s' matched '%s', revision %d (between %d and %d)\n", $node_type, $exclude_path, $path, $curr_rev, $first_rev, $last_rev);
				return 1;
			}
		} else {
			print STDERR sprintf("%s: exclude_path pattern '%s' matched '%s', revision %d\n", $node_type, $exclude_path, $path, $curr_rev);
			return 1;
		}
	}
	return 0;
}


# The filter list can specify revisions that should not be filtered:
#
#  donotfilter <revision-number>
#
# ...where <revision-number> is an integer revision in the dumpfile input stream.
#
sub parse_filters {
	my $self = shift;

	my @new_filters;
	$self->{'filter_directives'}->{'substitute_copyfrom_path'} = []; 	# Will be an array of hashes.
	foreach my $filter ( @{$self->filters} ) {
		my $rev;
		next if $filter =~ /^\s*#/; # Skip commment lines.
		next if $filter =~ /^\s*$/; # Skip empty lines.
		$filter =~ s:\s*#.*$:: ; # Strip comments.
		$filter =~ s:^\s*(.*?)\s*$:$1: ; # Trim leading and trailing whitespace.
		if ($filter =~ /^%do_not_filter (.*)/) {  # arg1 is revision for which to skip filtering
			$self->{'filter_directives'}->{'do_not_filter'}->{$1}++;
		} elsif ($filter =~ /^%substitute_copyfrom_path,(\d+),(\d+),(.*)/) {
			my $entry = {
				'rev' => $1,
				'copyfromrev' => $2,
				'copyfrompath' => $3
			};
			push(@{ $self->{'filter_directives'}->{'substitute_copyfrom_path'} }, $entry);
		} elsif ($filter =~ /^%exclude_path,([^,]+)(,(\d+):(\d+))?$/) {
			my %r = ( 'path' => $1 );
			if($3) {
				$r{'first_rev'} = $3;
				$r{'last_rev'} = $4;
			}
			push(@{ $self->{'filter_directives'}->{'exclude_path'} }, \%r);
		} else {
			push(@new_filters, $filter);
		}
	}
	$self->{'filters'} = \@new_filters;
}


# Take any 'substitute_copyfrom_path' directives into account when constructing a new copyfrom_path. If one of the 'substitute_copyfrom_path' paths is
# contained within the copypath, then a new SVN export is not needed.  Just substitute the indicated new-path into the portion of the copyfrom_path that matches.
#
sub new_copyfrom_path {
	my($self,$copypath,$curr_rev,$copyrev) = @_;

	my $import_path;
	foreach my $sub_cfp ( @{$self->filter_directives->{'substitute_copyfrom_path'} } ) {
		next unless ($sub_cfp->{'rev'} == $curr_rev and $sub_cfp->{'copyfromrev'} == $copyrev);
		my $sub_copypath = $sub_cfp->{'copyfrompath'};
		if ($copypath =~ m/^$sub_copypath/) {
			# Build the import sub-path from the $sub_copypath, and plug it into the original copy path to build the complete import path.
			my $import_subpath = $self->import_path($sub_copypath,$curr_rev,$copyrev); 
		  ($import_path = $copypath) =~ s:^$sub_copypath:$import_subpath: ;
			last;	# Should only ever need to handle one of these per revision.
		}
	}
	unless($import_path) {
		$import_path = $self->import_path($copypath,$curr_rev,$copyrev); 
		# If building a new import path, print out a suggested SVN export command.
		print STDERR sprintf("svn export --ignore-externals <src_repo_url>/$copypath\@$copyrev $import_path\n");
	}

	"$migration_dir/$import_path";
}

sub import_path {
	my($self,$copypath,$rev,$copyrev) = @_;
	(my $import_path = "${copypath}_$rev-copiedfrom-$copyrev") =~ s:/:-:g ;
	$import_path;
}

# Warn about this possibility:
# If a node is filtered out that deletes the tree at a higher level, and the same node is later added, it may result in a load error,
# since the effect in the filtered dumpfile will be to try to add the node twice.  The second add attempt will fail, since the node
# already exists, the intervening "delete" having been filtered out.
#
sub check_for_delete_node_that_is_a_component_of_a_filter {
	my $self = shift;
	my $path = shift;
  foreach my $filter ( @{$self->filters} ) {
		next if length($path) >= length($filter);	 # Only concerned about paths that are a subset of the filter.
		if ($filter =~ m/$path/) {
			print STDERR "WARNING: Filtered a DELETE node that may cause problems (such as a double-add): $path\n";
			last;
		}
  }
}
	
# Print the revision.  The temporary file will go away when no longer referenced.
#
sub print_revision {
	my $self = shift;
	my $rev = shift;
	my $fh = $rev->{'fh'};
	my $outfh = $self->outfh;
	$fh->seek( 0, SEEK_SET );
	while ( <$fh> ) {
		print $outfh $_ or last;
	}
	die "Problem copying revision to output!\n" if $!;
}


sub next_record_is_revision {
	my $self = shift;
	my $nr = $self->next_record;
	return 0 unless $nr;
  return 1 if $nr->type() eq 'revision';
  warn "Couldn't determine type of a record in revision " . $self->curr_rev_num if $nr->type() eq 'unknown';
  0;
}


sub get_size {
	my $self = shift;
  my $rec = shift;
  return 0 if ( $rec->get_header("Node-action") eq "delete"  or $rec->get_header("Node-kind") eq "dir" );
  return ($rec->get_header("Content-length") or 0);
}

1;
