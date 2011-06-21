#!/site/apps/perl/bin/perl

use Getopt::Long;

use FindBin;
use lib "$FindBin::Bin/../lib";

my $incr = 10_000;
my $first_rev;
my $last_rev;
my $proj;
my $tag;	# For tagging output filenames.
GetOptions(
	'first-rev=s' => \$first_rev,
	'last-rev=s' => \$last_rev,
	'project=s' => \$proj,
	'tag=s' => \$tag,
);

($first_rev and $last_rev) or die "Must specify non-zero --first-rev and --last-rev options";
$proj or die "Must specify --project option";

{ package Settings; do "$FindBin::Bin/.config"; }
my $basedir = $Settings::basedir;
my $oldRepoUrl = $Settings::oldRepoUrl;

print `mkdir -p $basedir/logs/$proj`;
print `mkdir -p $basedir/filtered-dumps/$proj`;
print `mkdir -p $basedir/refs/$proj`;
print `mkdir -p $basedir/dumps/$proj`;

my $filterFile = "$basedir/dumps/$proj/filters.txt";
-e $filterFile or die "Filter file not found: $filterFile";

chdir "$basedir/dumps";

my @dumpfiles = dumpfile_list($first_rev, $last_rev, $incr);

print "@dumpfiles\n";

my $filtered = "$proj.$first_rev-$last_rev$tag";
my $renumbered = "$filtered.renumbered";

my $migration_root = "$FindBin::Bin/..";
# Filter (catdumps.pl checks up-front that the dumpfiles all exist)...
print `time catdumps.pl @dumpfiles | $migration_root/bin/filter-dumps.pl --filter-file $filterFile 2> $migration_root/logs/$proj/$filtered.log > $migration_root/filtered-dumps/$proj/$filtered.dump `;

# Renumber...
#print `time renumber-revs.pl < $migration_root/filtered-dumps/$proj/$filtered.dump > $migration_root/filtered-dumps/$proj/$renumbered.dump 2> $migration_root/logs/$proj/$renumbered.log `;

# Make map file for propset-migration-refs.pl...
@maps = `grep 'svn export' $migration_root/logs/$proj/$filtered.log | sed -r 's!<src_repo_url>!$oldRepoUrl!'`;
open (F, ">$migration_root/refs/$proj/migration-refs-map.csv"); 
print F map { sprintf("%s,%s\n", ( m!($oldRepoUrl\S+) (.*)!)[1,0] ) } @maps;
close F;

# Set up migration-refs directory, and make svn-export.sh for creating copyfrom refs
print `mkdir -p $migration_root/refs/$proj/migration-refs`;
print `mkdir -p $migration_root/refs/$proj/workspace`;
print `grep 'svn export' $migration_root/logs/$proj/$filtered.log | sed -r 's!<src_repo_url>!$oldRepoUrl!' > $migration_root/refs/$proj/svn-export.sh`;
print `chmod +x $migration_root/refs/$proj/svn-export.sh`;

exit $?;


sub dumpfile_list {
	my($first_rev, $last_rev, $incr) = @_;

	my @dumpfiles;

	my $from_rev = $first_rev;
	my $remainder = ($first_rev % $incr);
	my $to_rev = ($first_rev - $remainder) + $incr;

	while ($to_rev < $last_rev) {
		push(@dumpfiles, dumpfile_name($from_rev, $to_rev));
		# Move from-rev and to-rev forward...
		$from_rev = $to_rev + 1;
		$to_rev += $incr;
	}

	push(@dumpfiles, dumpfile_name($from_rev, $last_rev));
	@dumpfiles;
}


sub dumpfile_name { sprintf("${Settings::dumpfile_prefix}.%06d-%06d.dump", @_ ) }
