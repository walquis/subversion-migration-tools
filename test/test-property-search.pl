#!/site/apps/perl/bin/perl -w

use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use Test::More tests => 6;

my $stderr;

BEGIN { use_ok('SVN::DumpTools::PropertySearch'); }	 # Test that "use"ing the module works OK.

# Does revision-based listing work? For path http://svpsvn/<repo>/projects/risk/libs/dependencies/internal,
# revision 52654 doesn't have properties, but 52661 does.

my $url = 'http://svpsvn/drw/projects/risk/libs/trunk/dependencies/internal/';
my @proptypes = ( 'svn:externals' );
my $propsFound = SVN::DumpTools::PropertySearch::find_properties( "$url", \@proptypes, 52654 );
is( keys %$propsFound, 0, "Should not be any svn:external properties on $url\@52654");
$propsFound = SVN::DumpTools::PropertySearch::find_properties( "$url", \@proptypes, 52661 );
is( (keys %$propsFound)[0], $url, "Should have found svn:externals properties for $url\@52661");
is( (keys %{$propsFound->{$url}})[0], 'svn:externals', "Should be one svn:external property on $url\@52661");

$url = 'http://svpsvn/drw/projects/algo/applications/dropcopy/trunk/src/main/com/drwtrading/fix/dropcopy/';
@proptypes = ( 'svn:keywords' );
$propsFound = SVN::DumpTools::PropertySearch::find_properties( $url, \@proptypes, 199904 );
my @paths = keys %$propsFound;
is( $#paths, 18, "Should be 19 paths with properties under $url\@199904");
is( $propsFound->{ $paths[0] }->{'svn:keywords'}, 'URL Date Author Revision', "Should have found a typical svn:keywords property for a path at $url\@199904");

exit 0;


#####################
# Helpers
#####################

# Re-init in-memory stderr for next set of tests.
sub init_stderr {
	my $stderr = shift;
	close(STDERR); # Re-open STDERR to an in-memory variable, so we can test output to STDERR.
	open STDERR, '>', $stderr or die "Can't re-open STDERR"; # Open STDERR to a variable.
}

sub read_filters {
  my $fname = shift;
  open(FILTER,$fname) or die "Couldn't open $fname for reading";
  my @filters = <FILTER>;
  chomp(@filters);
  return @filters;
}

