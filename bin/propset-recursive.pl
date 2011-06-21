#!/site/apps/perl/bin/perl
# Given: A Subversion hierarchy that has been exported with --ignore-externals, imported to a second repo, and 
# then checked out of the second repo to a workspace:
#
# When : called in that second repo's workspace...
#
# Then : Find all paths in the original repo that contain the indicated property type, and add 
# those properties to the corresponding place under the current workspace's hierarchy.
#
# Note that the original repo itself, not a local workspace, is traversed.
#
# Example:
# $ cd /data/repo-retire/migrations/snapshots/myProject-trunk
# $ propset-recursive.pl # defaults to processing svn:externals
#
# NOTES:
# - The source repo is assumed to be http://<oldRepoServer>/<oldRepoName>.
# - The destinaton repo defaults to http://<server>/repos/<repo-name>.  Use --repo to change it.
# - The default revision (of the source repo) is HEAD.
# - The path in both repos is assumed to be the same (so in particular this will NOT work for migrated references).
#
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use Getopt::Long;
use SVN::DumpTools::PropertySearch;

{ package Settings; do "$FindBin::Bin/.config"; }

my @proptypes = qw( svn:externals svn:keywords svn:eol-style svn:ignore );
my $noexec = 0;
my $revision = 'HEAD';
no warnings 'once';  # Turn off 'Name "Settings::oldRepoUrl" used only once: possible typo' for line below
my $repo = $Settings::oldRepoUrl;
my $proptypes;
GetOptions(
  'proptypes=s' => \$proptypes,
	'noexec' => \$noexec,
	'revision=s' => \$revision,
	'repo=s', => \$repo,
);

defined($proptypes) and @proptypes = split(",", $proptypes);

(my $svnpath = workspace_url() ) =~ s!http://[^/]+/repos/[^/]+(.*)!$repo$1!;

my $propsFound = SVN::DumpTools::PropertySearch::find_properties( $svnpath, \@proptypes, $revision );

# Process svn:externals props, if any.
foreach ( keys %{$propsFound} ) {
	next unless	defined($propsFound->{$_}->{'svn:externals'});
	(my $subpath = $_) =~ s!$svnpath/!! ;
	$subpath =~ s:/$:: ;
	$subpath ||= ".";
	my $propsfile = "$subpath/svn_props.txt";
	unless ($noexec) {
		open(F, ">$propsfile") or die "Couldn't open $propsfile for writing";
		print F $propsFound->{$_}->{'svn:externals'};
		close(F);
	}

	my $propsetCmd = "(cd $subpath; svn propset svn:externals --file svn_props.txt . ; rm svn_props.txt )\n";
	print STDERR "running propset: '$propsetCmd'...\n";
	$noexec or print `$propsetCmd`;
}

# Process other props, if any.
foreach my $proptype ( qw( svn:eol-style svn:keywords ) ) {
	foreach ( keys %{$propsFound} ) {
		next unless	defined($propsFound->{$_}->{$proptype});
		(my $subpath = $_) =~ s!$svnpath/!! ;
		my $propsetCmd = "svn propset $proptype '$propsFound->{$_}->{$proptype}' \"$subpath\"\n";
		print STDERR "running propset: '$propsetCmd'...\n";
		$noexec or print `$propsetCmd`;
	}
}

exit $?;


sub workspace_url { (map { (/URL: (.*)/)[0] } `svn info`)[0]; }
