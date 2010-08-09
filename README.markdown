iTunes Connect Tools
====================
A set of tools for developers who need to manage iTunes Connect data

Installation
-----------

Installation is very simple, but first you'll need to install [WWW::iTunesConnect][iTC].

1. Extract the tarball into a temporary directory
2. Copy the contents of the www subdirectory to some place accessible by your web server, then edit the index.php script to change username/password settings as needed
3. Copy the contents of the perl5 subdirectory to wherever you put your cron scripts
4. In the same directory, create config.pl with your iTunes username, password and any other options you need (see runner.pl -h for options). For example:
>user => 'bfoz@bfoz.net'  
>password => 'secret'  
5. Use tables.sql to create the necessary database and tables:
>mysql < tables.sql  
6. Configure cron to run runner.pl nightly. I run it at 5am, like so:
>0	5	\*	\*	\*	/home/bfoz/scripts/runner.pl

License
-------
Copyright 2008-2010 Brandon Fosdick <bfoz@bfoz.net>  
Released under the [BSD License][license]

History
-------

[Version 4][release4] - Released August 9, 2010

- Map finanacial report columns to database table columns
- Attempt to handle login notifications
- Don't use DBI's RaiseError=1
- Fix README links

[Version 3][release3] - Released February 6, 2010

- Switch to sequential release numbers
- Add basic error handling in runner.pl
- MySQL 5.0.32 doesn't like VARCHAR types being assigned as UNSIGNED NOT NULL
- New report columns that went into effect on April 1, 2009

Version 0.2 - Released January 29, 2008

- Checks the available reports against the database and only fetches new reports
- Fetches Daily and Weekly Sales/Trend Reports and monthly Financial Reports
- Commandline options for runner.pl can now be placed in the file config.pl in the same directory. This avoids having your password visible in your crontab.
- Statistics page shows daily averages

Version 0.1 - Released November 09, 2008

- First release to [Apple's OS X Developer forum][apple0]
- Simple hack to get original code posted by [Marco Vitanza][MarcoVitanza] reading from MySQL instead of text files
- Usable, but lots of rough edges


[apple0]: http://discussions.apple.com/thread.jspa?threadID=1765831&tstart=0
[license]: http://www.opensource.org/licenses/bsd-license.php
[iTC]: http://search.cpan.org/~bfoz/p5-WWW-iTunesConnect/
[MarcoVitanza]: http://marcovitanza.com/
[release3]: http://github.com/bfoz/itunesconnect-tools/tarball/v3
[release4]: http://github.com/bfoz/itunesconnect-tools/tarball/v4
