#!/site/apps/perl/bin/perl
# Given: A set of "migration-refs" hierarchies created using the 'svn export --ignore-externals'
#   commands spit out by the filter-projects.pl script, imported to the destination repo, and 
#   then checked out of that repo to a workspace.
#
# Given: A map file created from the 'svn export --ignore-externals' command, consisting of lines
#   in this format: the migration-refs directory, a comma, and the source URL for that directory.
#
# When : called in the migration-refs workspace...
#
# Then : iterate through all paths under migration-refs, look up the path in the map,
#   search Subversion for paths that contain the indicated property types, and add 
#   those properties to the corresponding place under the corresponding path in the current workspace.
#
# Note that the repo itself, not a local workspace, is traversed.
#
# Example:
# $ cd /data/repo-retire/migrations/refs/algo/migration-refs
# $ propset-migration-refs.pl --url_map_file ../migration-refs-map.csv 
#
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use Getopt::Long;
use SVN::DumpTools::PropertySearch;

{ package Settings; do "$FindBin::Bin/.config"; }

my $extern_prop = "svn:externals";
my $mergeinfo_prop = "svn:mergeinfo";
my @other_proptypes = qw( svn:keywords svn:eol-style svn:ignore svn:executable svn:mime-type svn:special );

my @proptypes = ( $extern_prop, $mergeinfo_prop, @other_proptypes );
our $noexec = 0;
my $proptypes;
no warnings 'once';  # Turn off 'Name "Settings::oldRepoUrl" used only once: possible typo' for line below
my $repo = $Settings::oldRepoUrl;
my $url_map_file;
GetOptions(
  'proptypes=s' => \$proptypes,
	'noexec' => \$noexec,
	'url_map_file=s' => \$url_map_file,
);
defined($url_map_file) or die "Usage: $0 --url_map_file <mapfile>";

defined($proptypes) and @proptypes = split(",", $proptypes);

my %url_map = url_map( $url_map_file );

@ARGV or @ARGV = <*>;

foreach my $path ( @ARGV ) {
	my($url,$revision) = split( '@', $url_map{$path} );
	print "Searching $url for properties ($path)...\n";
	process_props_for_path( $path, $url, \@proptypes, $revision);
}

exit $?;


sub url_map {
	my $fname = shift;
	my %url_map;
	open(F, $fname) or die "Couldn't open url map file '$fname' for reading";
	map { chomp; my($path, $url) = split(","); $url_map{$path} = $url;} <F>;
	%url_map;
}


sub process_props_for_path {
	my($migration_refs_root, $svnpath, $proptypes, $revision) = @_;
	$migration_refs_root ||= ".";
	my $propsFound = SVN::DumpTools::PropertySearch::find_properties( $svnpath, \@proptypes, $revision );

	# Process svn:externals props, if any.
	foreach ( keys %{$propsFound} ) {
		next unless	defined($propsFound->{$_}->{ $extern_prop });
		my $migration_refs_path = migration_refs_path_from_url($_, $svnpath, $migration_refs_root);
		my $propsfile = "$migration_refs_path/svn_props.txt";
		unless ($noexec) {
			open(F, ">$propsfile") or die "Couldn't open $propsfile for writing";
			print F $propsFound->{$_}->{ $extern_prop };
			close(F);
		}

		my $propsetCmd = "(cd $migration_refs_path; svn propset $extern_prop --file svn_props.txt . ; rm svn_props.txt )";
		print STDERR "running propset cmd: '$propsetCmd'...\n";
		$noexec or print `$propsetCmd`;
	}

	# Process other props, if any.
	foreach my $proptype ( @other_proptypes ) {
		foreach ( keys %{$propsFound} ) {
			next unless	defined($propsFound->{$_}->{$proptype});
			my $migration_refs_path = migration_refs_path_from_url($_, $svnpath, $migration_refs_root);
			my $propsetCmd = "svn propset $proptype '$propsFound->{$_}->{$proptype}' \"$migration_refs_path\"";
			print STDERR "running propset cmd: '$propsetCmd'...\n";
			$noexec or print `$propsetCmd`;
		}
	}

	# Warn if mergeinfo property found.
	foreach my $proptype ( ( $mergeinfo_prop ) ) {
		foreach ( keys %{$propsFound} ) {
			next unless	defined($propsFound->{$_}->{$proptype});
			my $migration_refs_path = migration_refs_path_from_url($_, $svnpath, $migration_refs_root);
			print STDERR "WARNING: Found $proptype property '$propsFound->{$_}->{$proptype}' at \"$migration_refs_path\"\n";
		}
	}
}


sub migration_refs_path_from_url {
	my($url,$svnpath,$migration_refs_root_path) = @_;
	my $migration_refs_path = $url;
	if ($migration_refs_path eq $svnpath) {    # If $migration_refs_path is a file, it's equal to $svnpath, therefore simply map to $migration_refs_root.
		$migration_refs_path = $migration_refs_root_path;
	} else {
		$migration_refs_path =~ s!$svnpath/!! ;	# Take off the leading Subversion path...
		$migration_refs_path =~ s:/$:: ;	# Take off the trailing slash...
		$migration_refs_path = "$migration_refs_root_path/$migration_refs_path";
	}
	$migration_refs_path;
}
