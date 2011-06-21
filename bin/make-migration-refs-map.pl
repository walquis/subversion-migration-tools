#!/site/apps/perl/bin/perl

# From a filter-project.pl log, extract a map for propset-migration-refs.pl to use.
# As of about 9 May 2011, filter-project.pl does this itself, so this script is dated.

print map { sprintf("%s,%s\n", ( m!(<src_repo_url>\S+) (.*)!)[1,0] ) } grep( /^svn export/, <STDIN>); 
