#!/site/apps/perl/bin/perl -w

use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use Test::More tests => 5;

my $stderr;

BEGIN { use_ok('SVN::DumpTools::RevisionMap'); }	 # Test that "use"ing the module works OK.

our %project1_revmap;
require 'data/project1.revmap.pl';	 # Loads %project1_revmap.

is( SVN::DumpTools::RevisionMap::rev_at_or_before('178234', \%project1_revmap), '4514', "Should have found 4514, an existing mapped revision");
is( SVN::DumpTools::RevisionMap::rev_at_or_before('181358', \%project1_revmap), '4654', "Find nearest mapped revision before 181356");

# Found a mergeinfo property.  Revision = 321139
my $mergeInfo_prop = <<"EOF";
/project1/branches/1.0.0.10593:178234-181358,181406,181431,181482,181635,182007,182247,182273,182347
/project1/branches/1.0.0.10642:185928-186534,187237-190998
/project1/branches/1.0.0.10689:194248
/project1/branches/1.0.0.10794:207029,207036,209181,212731,212836
/project1/branches/1.0.0.10845:216749-219403
/project1/branches/1.0.0.10993:238746,238756,238758,239279,240935,241010,241269,241352,241384
EOF
chomp($mergeInfo_prop);

my $mapped_mergeInfo_prop = <<"EOF";
/project1/branches/1.0.0.10593:4514-4654,4658,4660,4668,4673,4688,4699,4702,4708
/project1/branches/1.0.0.10642:4864-4891,4912-5043
/project1/branches/1.0.0.10689:5234
/project1/branches/1.0.0.10794:5829,5830,5892,6017,6023
/project1/branches/1.0.0.10845:6153-6278
/project1/branches/1.0.0.10993:6999,7007,7008,7022,7063,7068,7078,7081,7086
EOF
chomp($mapped_mergeInfo_prop);

is( SVN::DumpTools::RevisionMap::renumber_mergeinfo_property($mergeInfo_prop, 0, \%project1_revmap), $mapped_mergeInfo_prop, "Map a real svn:mergeinfo property");

my $mapped_mergeInfo_prop_offset_3 = <<"EOF";
/project1/branches/1.0.0.10593:4517-4657,4661,4663,4671,4676,4691,4702,4705,4711
/project1/branches/1.0.0.10642:4867-4894,4915-5046
/project1/branches/1.0.0.10689:5237
/project1/branches/1.0.0.10794:5832,5833,5895,6020,6026
/project1/branches/1.0.0.10845:6156-6281
/project1/branches/1.0.0.10993:7002,7010,7011,7025,7066,7071,7081,7084,7089
EOF
chomp($mapped_mergeInfo_prop_offset_3);

is( SVN::DumpTools::RevisionMap::renumber_mergeinfo_property($mergeInfo_prop, 3, \%project1_revmap), $mapped_mergeInfo_prop_offset_3, "Map same svn:mergeinfo property, but offset by 3 revisions");
