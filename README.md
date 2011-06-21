When my company first moved to Subversion, it had a small development team and no full-time engineering services person.  A single repository was created, and all the code went into it (as had been done with the previous source control system).

The company grew rapidly, and four years later the Subversion repository is monstrous.  The server still runs fine, but disk space and backups began to be a real problem.  It was time to pay down some technical debt.

This toolset arose for the purpose of splitting the monolithic legacy repo into project-specific repos. 

<h2>Procedure for migrating a given repo</h2>
This procedure uses the Perl tools at https://github.com/walquis/subversion-migration-tools.

1. As subversion user: Set up /data/repo-retire/migrations/dumps/<project>/filters.txt.  This is a simple filter spec that uses regexes to indicate which paths to include.  The filtering engine matches each pattern to the beginning of a Subversion Node-path. E.g.,...
<pre><code>
migration-refs
projects/someProject
projects/someOtherProject
%exclude_path,projects/someProject/someBigNolongerneededDirectory
%exclude_path,projects/someProject/temporarilyProblematicTree,32855:282707
</code></pre>
As indicated, you may exclude sub-paths within the included hiearchy, optionally specifying a range of revisions.
1. Find the revision in the old repo ("show all" in repo browser) from which to start migrating.  This will be the earliest revision across all the paths in filters.txt.
1. Turn the relevant paths readonly in the legacy repo.
1. From the prod server, "svnadmin dump" an incremental dump up to the next round number, e.g.,  legacy.92673-100000.dump (filter-project.pl expects it this way).  scp this file to the /data/repo-retire/migrations/dumps directory.
1. Filter the project, from first rev up to a round-number rev (.e.g., 320000), with *filter-project.pl*:
<pre><code>
$ filter-project.pl http://<host>/<repo> --project <myProject> --first-rev 120001 --last-rev 328000
</code></pre>
1. Construct the migration references under /data/repo-retire/migrations/refs/<myProject>
filter-project.pl creates /data/repo-retire/migrations/refs/<myProject>/svn-export.sh, which exports migration references corresponding to changes that it made when filtering.
<pre><code>
$ cd /data/repo-retire/migrations/refs/<myProject>/migration-refs
$ ../svn-export.sh
</code></pre>
1.1. Figure out what containing directories need to already exist, and mkdir them under refs/<myProject>/**/*
For instance, if filters.txt has a line like "projects/trading/myProject", then run "mkdir -p projects/trading".
1.2. Create the new repo, and *svn import \-\-no-ignore* the migration-refs and the directories that need to pre-exist. *\--no-ignore* is very important; if it's missing, then files that SVN typically ignores, like .so's, will be missing in the new repo.
<pre><code>
$ svnadmin create /data/retire/repos/myProject
$ cd /data/repo-retire/migrations/refs/<myProject>
$ svn import -m "containing dirs" projects http://localhost:8078/repos/myProject/projects
$ svn import -m "copyfrom refs" migration-refs http://localhost:8078/repos/myProject/migration-refs
</code></pre>
1.1. Search the migration-refs references for svn:externals, using propset-migration-refs.pl
(filter-project.pl created a migration-refs-map.csv for propset-migration-refs.pl to use).
<pre><code>
$ cd /data/repo-retire/migrations/refs/<myProject>/workspace
$ svn co http://localhost:8078/repos/myProject/migration-refs
$ cd migration-refs
$ propset-migration-refs.pl --url_map_file ../../migration-refs-map.csv
$ svn diff
$ svn ci -m "apply properties for copyfrom refs"  # If any properties were found and applied.
</code></pre>
1. Renumber the repo
Now that the migration refs and containing directories have been created, an offset for the repo can be determined.  The offset is equal to the revision of the new repo (typically 3).
<pre><code>
$ cd /data/repo-retire/migrations/filtered-dumps/myProject
$ renumber-revs.pl --revmap_offset 0 --rev_offset 3 < myProject.120001-328000.dump > myProject.120001-328000.renumbered.dump 2> ../../logs/myProject/myProject.120001-328000.renumbered.log
</code></pre>
1. "svnadmin load" the filtered/renumbered dumpfile
<pre><code>
$ cd /data/repo-retire/migrations/filtered-dumps/myProject
$ svnadmin load /data/repo-retire/repos/myProject/ < myProject.120001-328000.renumbered.dump > ../../logs/myProject/myProject.renumbered.120001-328000.load.log 2>&1
</code></pre>
1. Verify the changes by exporting HEAD revisions from old and new, and "diff -rq".
1. rsync the migrated repo to the production location.
1. Softlink the hooks from /data/subversion/hooks:
<pre><code>
$ cd /data/subversion/repos/<repo>/hooks
$ for i in commit-size.pl label-access-control.cfg check-case-insensitive.pl label-access-control.pl pre-commit pre-revprop-change README tags_protect_hook.pl
> do
>   ln -s ../../../hooks/$i
> done
$ rm *.tmpl
</code></pre>
1. Set up the relevant access in the production repo.
1. Switch over TeamCity.  This usually consists of changing one or two VCS roots, and adding a "Project.SvnRepository=http://<host>/repos/myProject" environment variable to the RC build configs.
1. Set up the repo in FishEye (or switch it over and re-index, if it already exists for the original Subversion repo).
1. Fix the dates in the first two or three revisions to come earlier than the initial migrated revision; otherwise, FishEye may get confused.  You will have to set up the revprop hook to allow this.  Here is an example from Perl...
<pre><code>
svn ps svn:date 2008-03-21T00:00:00.000000Z --revprop -r1 http://<host>/repos/<site>perl
svn ps svn:date 2008-03-21T00:00:01.000000Z --revprop -r2 http://<host>/repos/<site>perl
</code></pre>

<h2>Some gotchas</h2>

* A handful of files in e.g., <site>perl use Subversion variables ($URL$, etc).  In the course of checking-out or exporting such files (for resolving copyfrom-paths, for instance), Subversion will fill in the values of these variables.  When they are imported and then subsequently referenced by modified node-paths during an "svnadmin load", a checksum error will result, since their content has changed.  WORKAROUND: After exporting, unset these variables, and run md5sum on the file to confirm that the checksum matches the corresponding Node-copyfrom-path's checksum.
* *Make sure that the migrated repo's UUID is different than the legacy repo's UUID*, otherwise TeamCity will get confused when it encounters svn:externals.  In particular, TeamCity uses the same revision for externals that appear to belong to the same repo that it's checking out.  You will see a failure like this:
<pre><code>
[14:08:57]: [VCS Root: <site>perl] Subversion update_external problem for /data/site/ ... jars/3rd/fastutil: svn: Unable to find repository location for 'http://<host>/legacy-repo/jars/3rd/fastutil/5.1.5/jar' in revision '11,488'
</code></pre>
The fix is easy: On the SVN server, use "svnadmin setuuid <repo> <uuid>" to change the uuid.
* *Sometimes included pathnames change, especially early in the history*.  If this happens, the filter will appear to succeed, but the "svnadmin load" will fail, since the filter missed the path that was renamed.
To fix, add the additional pathname and re-run the filter.


