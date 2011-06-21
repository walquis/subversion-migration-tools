#!/site/apps/perl/bin/perl -w

use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use Test::More tests => 53;

use SVN::DumpTools::Filter;

my $stderr;

BEGIN { use_ok('SVN::DumpTools::Filter'); }	 # Test that "use"ing the module works OK.

my($out, $outfh);
my($input, $infh, $infile);
my $oldTerminator;
my @filters;
my ($rev, $revs_dropped);
my $f;


print "\nTesting exclude_path directive...\n\n";

init_stderr(\$stderr);
$infile = "$FindBin::Bin/data/filter-specific-paths.dump";

$oldTerminator = $/;
undef $/; # Slurp entire file...
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open(IN, $infile);
$input = <IN>; close IN;	# ...into a variable.
$/ = $oldTerminator;	# Restore original line terminator

open($infh, '<', \$input);	 # Open a read filehandle on a variable.
open($outfh, '>', \$out);  # Open output filehandle to a variable.
select((select($infh), $|=1)[0]);
@filters = (
	'projects/myProject',
	'%exclude_path,projects/myProject.*/bin/x86/.*MarketData\.log.*'
);

$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh);

$rev = $f->next_filtered_revision;
$f->print_revision($rev);	# To STDOUT, which has been dup'd to $out...
is($rev->{'revision-number'}, '1', "Should have gotten revision 1");
my @nodepaths = grep(/^Node-path: /, split("\n", $out));
# In this revision, there should be no paths matching "MarketData.log".
my @paths = grep(m:MarketData\.log:, @nodepaths);
is($#paths, -1, "Should not have seen any paths matching 'MarketData.log' in revision 1");
is($#nodepaths, 8, "Should have seen nine paths besides those matching 'MarketData.log'.");

# Now test excluding paths with spaces...

init_stderr(\$stderr);
$infile = "$FindBin::Bin/data/filter-specific-paths.dump";

$oldTerminator = $/;
undef $/; # Slurp entire file...
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open(IN, $infile);
$input = <IN>; close IN;	# ...into a variable.
$/ = $oldTerminator;	# Restore original line terminator

open($infh, '<', \$input);	 # Open a read filehandle on a variable.
open($outfh, '>', \$out);  # Open output filehandle to a variable.
select((select($infh), $|=1)[0]);
@filters = (
	'projects/myProject',
	'%exclude_path,projects/myProject.*/bin/x86/.*Market Data\.log.*'
);

$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh);

$rev = $f->next_filtered_revision;
$f->print_revision($rev);	# To STDOUT, which has been dup'd to $out...
is($rev->{'revision-number'}, '1', "Should have gotten revision 1");
@nodepaths = grep(/^Node-path: /, split("\n", $out));
# In this revision, there should be no paths matching "Market Data.log".
@paths = grep(m:Market Data\.log:, @nodepaths);
is($#paths, -1, "Should not have seen any paths matching 'Market Data.log' in revision 1");
is($#nodepaths, 9, "Should have seen ten paths besides those matching 'MarketData.log'.");

init_stderr(\$stderr);
$infile = "$FindBin::Bin/data/filter-specific-paths.dump";

$oldTerminator = $/;
undef $/; # Slurp entire file...
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open(IN, $infile);
$input = <IN>; close IN;	# ...into a variable.
$/ = $oldTerminator;	# Restore original line terminator

open($infh, '<', \$input);	 # Open a read filehandle on a variable.
open($outfh, '>', \$out);  # Open output filehandle to a variable.
select((select($infh), $|=1)[0]);
@filters = (
	'projects/myProject',
	'',
	'# A line with only a comment',
	'%exclude_path,projects/myProject.*/bin/x86/.*MarketData\.log.*,2:3 # A comment'
);

$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh);

$rev = $f->next_filtered_revision;  # revision 1
$f->print_revision($rev);	# To STDOUT, which has been dup'd to $out...
@nodepaths = grep(/^Node-path: /, split("\n", $out));
# In this revision, "MarketData.log" should not have been filtered.
@paths = grep(m:MarketData\.log:, @nodepaths);
is($#paths, 2, "Revision 1 should not have any MarketData.log paths filtered out.");
is($#nodepaths - $#paths, 9, "Should have seen nine paths in addition to 'MarketData.log'.");

$rev = $f->next_filtered_revision;  # revision 2
$f->print_revision($rev);	# To STDOUT, which has been dup'd to $out...
is($rev->{'revision-number'}, '2', "Should have gotten revision 2");
@nodepaths = grep(/^Node-path: /, split("\n", $out));
is($#nodepaths, 13, "Should be two additional paths in stdout (All 'MarketData.log' paths in revision 2 should have been filtered out).");

$rev = $f->next_filtered_revision;  # revision 3
$f->print_revision($rev);	# To STDOUT, which has been dup'd to $out...
is($rev->{'revision-number'}, '3', "Should have gotten revision 3");
@nodepaths = grep(/^Node-path: /, split("\n", $out));
is($#nodepaths, 15, "Should be two additional paths in stdout (All 'MarketData.log' paths in revision 3 should have been filtered out).");

$rev = $f->next_filtered_revision;  # revision 4
$f->print_revision($rev);	# To STDOUT, which has been dup'd to $out...
is($rev->{'revision-number'}, '4', "Should have gotten revision 4");
@nodepaths = grep(/^Node-path: /, split("\n", $out));
is($#nodepaths, 20, "Expected 5 more paths (no paths in revision 4 should have been filtered out).");

print "\nTesting that filter pattern matches beginning of Node-path line...\n\n";

init_stderr(\$stderr);
$infile = "$FindBin::Bin/data/aRepo.matchBeginningOfLine.dump";

$oldTerminator = $/;
undef $/; # Slurp entire file...
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open(IN, $infile);
$input = <IN>; close IN;	# ...into a variable.
$/ = $oldTerminator;	# Restore original line terminator

open($infh, '<', \$input);	 # Open a read filehandle on a variable.
open($outfh, '>', \$out);  # Open output filehandle to a variable.
select((select($infh), $|=1)[0]);
@filters = read_filters("$FindBin::Bin/data/perl-repo_filters.txt");

$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh);

$rev = $f->next_filtered_revision;
is( $rev->{'node-count'}, 0, "Filtering revision 188 should have dropped one revision (testing that filters match from beginning of line)");
$rev = $f->next_filtered_revision;
is( $rev->{'node-count'}, 1, "Should have gotten a revision");
like( $stderr, qr/WARNING: Revision 139.*Copyfrom-path not included .*Copyfrom-rev = 137.* projects.perl/, "STDERR should warn that in revision 139, a path's copyfrom-rev 137 is not included by the filter"); 


init_stderr(\$stderr);
$infile = "$FindBin::Bin/data/aRepo.86011.dump";

$oldTerminator = $/;
undef $/; # Slurp entire file...
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open(IN, $infile);
$input = <IN>; close IN;	# ...into a variable.
$/ = $oldTerminator;	# Restore original line terminator

open($infh, '<', \$input);	 # Open a read filehandle on a variable.
open($outfh, '>', \$out);  # Open output filehandle to a variable.
select((select($infh), $|=1)[0]);
@filters = (
	'projects/some/thing/myProject',
	'%substitute_copyfrom_path,86011,85980,projects/some/thing/oldMyProject/branches/tfs'
);

$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh);

print "\nTesting substitute_copyfrom_path directive on 86011, which has included records...\n\n";

$rev = $f->next_filtered_revision;
$f->print_revision($rev);
is($rev->{'revision-number'}, '86011', "Should have gotten revision 86011");
my @copyfrompaths = grep(/^Node-copyfrom-path/, split("\n", $out));
# In this revision, all of the Node-copyfrom-paths should have been changed according to the above filter directive;
my @changedpaths = grep(m:migration-refs/projects-some-thing-oldMyProject-branches-tfs_86011-copiedfrom-85980:, @copyfrompaths);
is($#copyfrompaths, 3, "Should have seen 4 copyfrom-paths");
is($#copyfrompaths, $#changedpaths, "All of the Node-copyfrom-paths should have been changed to 'migration-refs/projects-trading...'");


print "\nTesting 20747-20748 with no filtering...\n\n";

init_stderr(\$stderr);
$infile = "$FindBin::Bin/data/aRepo.20747-20748.dump";

$oldTerminator = $/;
undef $/; # Slurp entire file...
open(IN, $infile);
$input = <IN>; close IN;	# ...into a variable.
$/ = $oldTerminator;	# Restore original line terminator

undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open($infh, '<', \$input);	 # Open a read filehandle on a variable.
open($outfh, '>', \$out);  # Open output filehandle to a variable.
select((select($infh), $|=1)[0]);
$f = SVN::DumpTools::Filter->new( ['projects'], $infh, $outfh ,1);	 # $debug = 1
like($f, qr/^SVN::DumpTools::Filter=HASH/, "Should initialize an instance of SVN::DumpTools::Filter");

like( sprintf("%s",$f->next_record), qr/SVN::Dump::Record=HASH/, "next_record should be initialized to an SVN::Dump::Record");

$rev = $f->next_filtered_revision;
$f->print_revision($rev);
is($rev->{'revision-number'}, '20747', "Should have gotten revision 20747");

$rev = $f->next_filtered_revision;
$f->print_revision($rev);
is($rev->{'revision-number'}, '20748', "Should have gotten revision 20748");

ok( !defined($f->next_record), "After 2nd (and last) revision, next_record should be undef");
like( $stderr, qr/WARN.*20747.*Copyfrom-rev 20692 not included/, "STDERR should warn that in 20747, a path's copyfrom-rev 20692 is not included by the filter"); 
like( $stderr, qr/WARN.*20748.*Copyfrom-rev 20692 not included/, "STDERR should warn that in 20748, a path's copyfrom-rev 20692 is not included by the filter"); 
unlike( $stderr, qr/Filtered/, "STDERR should not show any nodes filtered"); 
is( $out, $input, "In & out should be the same for 20747-20748 filtering by filter 'projects'");


print "\nTesting 57127-57128 with full filter file...\n\n";

init_stderr(\$stderr);

@filters = read_filters("$FindBin::Bin/data/sjtl_filters.txt");
$infile = "$FindBin::Bin/data/aRepo.57127-57128.dump";
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open($infh, $infile) or die "Couldn't open $infile for reading";
$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh, 1);

$revs_dropped = $f->filter_revisions;	# Test top-level filtering method.

is( $revs_dropped, 1, "Filtering 57127-57128 should have dropped one revision");

like( $stderr, qr/WARN.*57128.*Copyfrom-rev 57127 not included/, "STDERR should have a warning about copyfrom-rev 20692, in revision 20747"); 

# Do 57127-57128 again, and make sure dropped node counts are correct for each revision...
init_stderr(\$stderr);
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open($infh, $infile) or die "Couldn't open $infile for reading";
$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh );
$rev = $f->next_filtered_revision;	 # 57127

is($rev->{'node-count'}, 0, "All paths from 57127 should have been filtered out");
is($rev->{'original-node-count'}, 23, "Original count of nodes in 57127");

$rev = $f->next_filtered_revision;	# 57128

is($rev->{'node-count'}, 1, "One path from 57128 should remain");
is($rev->{'original-node-count'}, 2, "Original count of nodes in 57128");

like( $stderr, qr/WARN.*57128.*Path .*projects\/sjtl\/sdj\/models.*Copyfrom-path not included by the filter.*Copyfrom-path = projects\/aProject\/Projects\/blah\/blah/, "STDERR should warn that 57128's aProject copy-from-path will not be included by the filter"); 

like( $stderr, qr/Changing Node-copyfrom-path.*migration-refs\/projects-aProject-Projects-blah-blah_57128-copiedfrom-57127/s, "Change the Node-copyfrom-path to a migration-refs location"); 

# print $stderr;
print "\nTesting with ancient dump excerpt, 21022-21023...\n\n";
# Re-init in-memory stderr for next set of tests.
init_stderr(\$stderr);
$infile = "$FindBin::Bin/data/aRepo.21022-21023.dump";
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open($infh, $infile) or die "Couldn't open $infile for reading";
$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh );
$rev = $f->next_filtered_revision;	# Has a "Delete projects/sjtl/sdj" node...should warn about this

is($rev->{'revision-number'}, 21022, "Should have processed 21022");
is($rev->{'node-count'}, 0, "Should have filtered all nodes out of 21022");

unlike( $stderr, qr/WARN.*Filtered a DELETE node that may cause problems (such as a double-add).*projects\/sjtl\/sdj/s, "21022 shouldn't throw a 'Filtered a DELETE node' warning"); 

$rev = $f->next_filtered_revision;	# Has a "Delete projects/sjtl/sdj" node...should warn about this
like( $stderr, qr/WARN.*Filtered a DELETE node that may cause problems.*projects\/sjtl\/sdj/s, "Should find a problematic 'delete' node (a component of one of the filters)"); 


print "\nTesting exclusion of revisions from filtering...\n\n";

init_stderr(\$stderr);
$infile = "$FindBin::Bin/data/anotherRepo.0-1.small.dump";
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open($infh, $infile) or die "Couldn't open $infile for reading";
$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh );
$revs_dropped = $f->filter_revisions;	# Test top-level filtering method.
is( $revs_dropped, 0, "Given the donotfilter directives in sjtl_filters.txt, filtering 0-1 shouldn't drop any revisions");

# Make sure the 0th revision is dropped.
init_stderr(\$stderr);
@filters = read_filters("$FindBin::Bin/data/sjtl_filters.drop_zero.txt");
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open($infh, $infile) or die "Couldn't open $infile for reading";
open($outfh, '>', \$out);  # Open output filehandle to a variable.
$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh, 1);
$revs_dropped = $f->filter_revisions;	# Test top-level filtering method.

like($stderr, qr/Dropped empty revision 0/, "STDERR should say revision 0 was dropped");
unlike($out, qr/^Revision-number: 0/, "Make sure Revision 0 was dropped, per filtering directive");

# Make sure the 1th revision is dropped.
init_stderr(\$stderr);
@filters = read_filters("$FindBin::Bin/data/sjtl_filters.drop_one.txt");
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open($infh, $infile) or die "Couldn't open $infile for reading";
open($outfh, '>', \$out);  # Open output filehandle to a variable.
$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh, 1);
$revs_dropped = $f->filter_revisions;	# Test top-level filtering method.

unlike($stderr, qr/Dropped empty revision 0/, "STDERR should NOT say revision 0 was dropped, per filtering directive");
like($stderr, qr/Dropped empty revision 1/, "STDERR should say revision 1 was dropped, per filtering directive");
unlike($out, qr/Revision-number: 1/, "Make sure Revision 1 was dropped, per filtering directive");


# Make sure the 310074th revision is dropped.
init_stderr(\$stderr);
@filters = read_filters("$FindBin::Bin/data/sjtl_filters.txt");
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
$infile = "$FindBin::Bin/data/aRepo.310074-310075.dump";
open($infh, $infile) or die "Couldn't open $infile for reading";
open($outfh, '>', \$out);  # Open output filehandle to a variable.
$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh, 1);
$revs_dropped = $f->filter_revisions;	# Test top-level filtering method.

is( $revs_dropped, 1, "filter_revisions() should have dropped 1 revision");
like($stderr, qr/Dropped empty revision 310074/, "STDERR should say revision 310074 was dropped");
unlike($stderr, qr/Dropped empty revision 310075/, "STDERR should NOT say revision 310075 was dropped");
unlike($out, qr/Revision-number: 310074/, "Make sure revision 310074 was filtered from the output");


init_stderr(\$stderr);
$infile = "$FindBin::Bin/data/aRepo.243913.dump";
undef $infh;	# Must do this, since $infh was changed to a $SVN::Dump::Reader object by the prev SVN::Dump object.
open($infh, $infile) or die "Couldn't open $infile for reading";
open($outfh, '>', \$out);  # Open output filehandle to a variable.
$f = SVN::DumpTools::Filter->new( \@filters, $infh, $outfh );
$revs_dropped = $f->filter_revisions;	# Test top-level filtering method.
is($revs_dropped, 1, "When checking paths of dropped nodes, handle paths with regex metachars ( [...] )");


exit $?;

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

