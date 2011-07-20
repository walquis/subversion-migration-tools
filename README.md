When my company first moved to Subversion, the dev team was small, with no dedicated build engineer.  A single repository was created for all teams to share, as with the previous source control system.

The company grew rapidly, and now the Subversion repo is monstrous.  The server still runs fine, but disk space and backups have begun to be a real problem.  Time to pay down some technical debt...

This tool set arose from the ten-month task of splitting our monolithic legacy repo into many team-oriented repos.  (Before embarkingon it, I asked each team if they wanted history migrated, and virtually everyone said "yes"; otherwise, the job would have been much simpler!)

Migrating a repo
------------
The general approach: Start with an "svnadmin dump" of the legacy repo.  I dumped the legacy repo in increments of 10,000 revisions, in order to facilitate manual editing of dumpfiles.  The filter-project.pl tool assumes this dumpfile layout, e.g., ***repo***.000000-010000.dump, ***repo***.010001-020000.dump, etc.  (As the tools matured, manual edits became less necessary).  When I did need to edit, I relied heavily on *vim*.  After corrupting a dumpfile or two, I quickly learned to **set binary** in my ~/.vimrc!

After establishing a repo dump, set up filters for the project in play, and apply those filters to the appropriate time-slice of the repo dump to produce a filtered dump.  During this step, take note of path references that point outside the filters, so that they can be resolved later.  [In fact, the dumpfile is modified at this to point to those references, which are then created programmatically by an **svn-export.sh** script generated as output from this step].

Renumber the revisions in the filtered dump, including copyfrom and mergeinfo references.

Create snapshots that correspond to path references from outside the filters; create a new repo; import the snapshots; create the containing directories at which the filters start; and load the filtered dumpfile into the new repo.

### Step-by-step procedure
The later steps assume a TeamCity/FishEye environment; ignore as necessary.

1. As subversion user: Set up /data/repo-retire/migrations/dumps/***myProject***/filters.txt.  This is a simple filter spec that uses regexes to indicate which paths to include.  The filtering engine matches each pattern to the beginning of a Subversion Node-path. E.g.,...
<pre>
migration-refs
projects/someProject
projects/someOtherProject
%exclude_path,projects/someProject/someBigNolongerneededDirectory
%exclude_path,projects/someProject/temporarilyProblematicTree,32855:282707
</pre>
As indicated in the example, sub-paths falling within the included hierarchy may be excluded, optionally specifying a range of revisions.  This came in handy for snipping out a chunk of history for one project that included huge files.
1. Find the revision in the old repo ("show all" in the TortoiseSVN repo browser's log window is good for this) from which to start migrating.  This will be the smallest revision in the history of all the paths in filters.txt.
1. Turn the relevant paths read-only in the legacy repo.
1. From the prod server, "svnadmin dump" an incremental dump up to the nearest 10,000, e.g., legacy.092673-100000.dump (filter-project.pl expects it this way).  scp this file to the /data/repo-retire/migrations/dumps directory.
1. Filter the project, from the first rev up to a rev that is a multiple of 10,000 (.e.g., 320000), with *filter-project.pl*:

		$ filter-project.pl --project myProject --first-rev 120001 --last-rev 328000

1. Construct the migration references under /data/repo-retire/migrations/refs/myProject
filter-project.pl creates /data/repo-retire/migrations/refs/myProject/svn-export.sh, which exports migration references corresponding to changes that it made when filtering.
<pre>
		$ cd /data/repo-retire/migrations/refs/myProject/migration-refs
		$ ../svn-export.sh
</pre>
>> a. Figure out what containing directories need to already exist, and mkdir them under refs/myProject/\*\*/\*.  For instance, if filters.txt has a line like "projects/trading/myProject", then run "mkdir -p projects/trading".  
>> b. Create the new repo, and *svn import \-\-no-ignore* the migration-refs and the directories that need to pre-exist. *\--no-ignore* is very important; if it's missing, then files that SVN typically ignores, like .so's, will be missing in the new repo.
<pre>
		$ svnadmin create /data/retire/repos/myProject
		$ cd /data/repo-retire/migrations/refs/myProject
		$ svn import -m "containing dirs" projects http://localhost:8078/repos/myProject/projects
		$ svn import -m "copyfrom refs" migration-refs http://localhost:8078/repos/myProject/migration-refs
</pre>
>> c. Search the migration-refs references for svn:externals, using propset-migration-refs.pl
(filter-project.pl created a migration-refs-map.csv for propset-migration-refs.pl to use).
<pre>
		$ cd /data/repo-retire/migrations/refs/myProject/workspace
		$ svn co http://localhost:8078/repos/myProject/migration-refs
		$ cd migration-refs
		$ propset-migration-refs.pl --url_map_file ../../migration-refs-map.csv
		$ svn diff
		$ svn ci -m "apply properties for copyfrom refs"  # If any properties were found and applied.
</pre>
1. Renumber the repo
Now that the migration refs and containing directories have been created, an offset for the repo can be determined.  The offset is equal to the revision of the new repo (typically 3).

		$ cd /data/repo-retire/migrations/filtered-dumps/myProject
		$ renumber-revs.pl --revmap_offset 0 --rev_offset 3 < myProject.120001-328000.dump > myProject.120001-328000.renumbered.dump 2> ../../logs/myProject/myProject.120001-328000.renumbered.log

1. "svnadmin load" the filtered/renumbered dumpfile

		$ cd /data/repo-retire/migrations/filtered-dumps/myProject
		$ svnadmin load /data/repo-retire/repos/myProject/ < myProject.120001-328000.renumbered.dump > ../../logs/myProject/myProject.renumbered.120001-328000.load.log 2>&1

1. Verify the changes by exporting HEAD revisions from old and new, and "diff -rq".
1. rsync the migrated repo to the production location.
1. Softlink the hooks from /data/subversion/hooks:

		$ cd /data/subversion/repos/myrepo/hooks
		$ for i in commit-size.pl label-access-control.cfg check-case-insensitive.pl label-access-control.pl pre-commit pre-revprop-change README tags_protect_hook.pl
		> do
		>   ln -s ../../../hooks/$i
		> done
		$ rm *.tmpl

1. Set up the relevant access in the production repo.
1. Switch over TeamCity.  This usually consists of changing one or two VCS roots, and adding a "Project.SvnRepository=http://myhost/repos/myProject" environment variable to the RC build configs.
1. Set up the repo in FishEye (or switch it over and re-index, if it already exists for the original Subversion repo).
1. Fix the dates in the first two or three revisions to come earlier than the initial migrated revision; otherwise, FishEye may get confused.  You will have to set up the revprop hook to allow this.  Here is an example from Perl...

		svn ps svn:date 2008-03-21T00:00:00.000000Z --revprop -r1 http://myhost/repos/siteperl
		svn ps svn:date 2008-03-21T00:00:01.000000Z --revprop -r2 http://myhost/repos/siteperl

Some gotchas
------------

* A handful of files in e.g., __site__perl use Subversion variables ($URL$, etc).  In the course of checking-out or exporting such files (for resolving copyfrom-paths, for instance), Subversion will fill in the values of these variables.  When they are imported and then subsequently referenced by modified node-paths during an "svnadmin load", a checksum error will result, since their content has changed.  WORKAROUND: After exporting, unset these variables, and run md5sum on the file to confirm that the checksum matches the corresponding Node-copyfrom-path's checksum.
* *Make sure that the migrated repo's UUID is different than the legacy repo's UUID*, otherwise TeamCity will get confused when it encounters svn:externals.  In particular, TeamCity uses the same revision for externals that appear to belong to the same repo that it's checking out.  You will see a failure like this:

		[14:08:57]: [VCS Root: __site__perl] Subversion update_external problem for /data/site/ ... jars/3rd/fastutil: svn: Unable to find repository location for 'http://myhost/legacy-repo/jars/3rd/util/5.5/jar' in revision '11,488'

The fix is easy: On the SVN server, use "svnadmin setuuid myrepo &lt;uuid&gt;" to change the uuid.
* *Sometimes included pathnames change, especially early in the history*.  If this happens, the filter will appear to succeed, but the "svnadmin load" will fail, since the filter missed the path that was renamed.
To fix, add the additional pathname and re-run the filter.
