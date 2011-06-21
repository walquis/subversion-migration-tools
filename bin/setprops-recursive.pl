#!/site/apps/perl/bin/perl
# Goal: Duplicate svn hierarchy A in another repo, including svn:externals properties.
#
# Given SVN workspaces A and B with identical hierarchies, where A has svn:external properties but B doesn't,
#   and B has been imported into another repo from A, and checked out again:
# Recurse through A, setting svn:externals properties at corresponding points in B.

use strict;
use warnings;

use File::Find;
use File::Temp qw/ :seekable /;
use Getopt::Long;

my $no_exec = 0;
GetOptions(
  'no-exec' => \$no_exec,
);

die "USAGE: $0 svn-workspace-with-externals  svn-workspace-that-needs-externals\n" if $#ARGV < 1;

our $srcWs = $ARGV[0];
our $dstWs = $ARGV[1];
chomp(our $startDir = `pwd`);

find(\&process_externals, $srcWs);

sub process_externals {
	return if -f;	 # Externals wouldn't be set on files...
	return if $_ eq ".";
	return if $_ eq "..";
	if (/^\.svn$/) {
		$File::Find::prune = 1;
		return;
	}

	my $cmd = "svn propget svn:externals '$_' ";	# $_ is the file in the current directory.
	chomp(my $externs = `$cmd`);

	if ($externs) {
		print "Found externals for $File::Find::name: \n\t" . join("\n\t", split("\n", $externs)). "\n";
		my $tmpfh = File::Temp->new(UNLINK=>1);
		print $tmpfh $externs;
		close $tmpfh;
		(my $subDir = $File::Find::name) =~ s:$srcWs/:: ;
		my $cmd = "svn propset --file " . $tmpfh->filename . " svn:externals '$startDir/$dstWs/$subDir'";
		print ($no_exec ? "$cmd\n" : `$cmd`);
	}
}
