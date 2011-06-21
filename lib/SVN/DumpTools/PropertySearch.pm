#!/site/apps/perl/bin/perl
# Given an SVN URL, recursively find (via pre-order traversal) all nodes with an instance
# of the specified property types.
#
package SVN::DumpTools::PropertySearch;
use strict;
use warnings;
use File::Basename;

our $our_revision;

sub find_properties {
	my $url = shift;
	my $proptypes = shift;
	$our_revision = shift;
	traverse_nodes( trailing_slash_if_dir($url), \&propget, $proptypes, my $properties = {} );
}


sub traverse_nodes {
	my ($node, $operator, $proptypes, $properties ) = @_;

	foreach my $proptype ( @$proptypes ) {
		my $propval = &$operator($node, $proptype);
		$propval and $properties->{$node}->{$proptype} = $propval;
	}

	if ($node =~ m:/$:) {  # Directories end in slashes; recurse into them...
		map { chomp; traverse_nodes( "$node$_", $operator, $proptypes, $properties ) } `svn list '$node\@$our_revision'`;
	}
	$properties;
}


# Could use 'propget -R --xml' and avoid explicit recursion, but then you have to parse XML output...
sub propget {
	my($node, $proptype) = @_;

	if ($proptype eq 'svn:externals') {
		return unless $node =~ m:/$:;   # Directories returned from "svn list" end in slashes
	}

	my $cmd = "svn propget $proptype '$node\@$our_revision' ";	# $_ is the file in the current directory.
	chomp(my $propval = `$cmd`);

	$propval =~ s:^\s*(.*)\s*$:$1:;	# Trim leading and trailing whitespace
	$propval or undef;
}


sub trailing_slash_if_dir {
	my $url = shift;
	return $url if $url =~ m:/$: ;	# Assume it's a dir if trailing slash

	chomp(my $out = `svn list '$url\@$our_revision'`);
	if ($out eq basename($url)) {
		$url =~ s:/+$:/:; # Remove multiple trailing slashes, if found.
	} else {
		$url .= "/";
	}
	$url;
}

1;
