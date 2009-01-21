#! /usr/bin/perl
# $Id: runner.pl,v 1.14 2009/01/21 07:55:48 bfoz Exp $

use strict;
use WWW::iTunesConnect;
use DBI;
use Getopt::Std;

sub usage
{
    print "./runner.pl [options]\n";
    print "    -u user	iTunes Connect username\n";
    print "    -p pass	iTunes Connect password\n";
    print "    -d dbname	Database name\n";
    print "    -D driver	Database driver (mysql, ...)\n";
    print "    -U user	Database username\n";
    print "    -P pass	Database password\n";
    print "    -s dir	Save reports to dir instead of to a table\n";
    print "    -c path	Path to config file (defaults to ./config.pl)\n";
    die;
}

# Default configuration options
my %config = (	'user' => undef,
		'password' => undef,
		'dbname' => 'iTunesConnect',
		'dbuser' => 'root',
		'dbpass' => undef,
		'driver' => 'mysql',
		'path' => undef,
		'config' => 'config.pl');

# Parse the command line options
my %options;
getopts('u:p:d:D:U:P:s:c:', \%options) or usage();
# Handle -c early so the default config file path can be overriden
$config{config} = $options{c} if $options{c};
delete $options{config};	# Don't need this one any more

# Config file overrides defaults
my %in = do $config{config};
@config{keys %in} = values %in;

my %opt2config = (  'u' => 'user',
                    'p' => 'password',
                    'd' => 'dbname',
                    'U' => 'dbuser',
                    'P' => 'dbpass',
                    'D' => 'mysql',
                    's' => 'path',
                 );

# Command line options override defaults and config.pl
@config{@opt2config{keys %options}} = values %options;

die "Need iTunes username and password\n" unless $config{user} and $config{password};
my $itc = WWW::iTunesConnect->new(user=>$config{user}, password=>$config{password});

# If only saving latest report to file, do it and then exit
if( $config{path} )
{
    my %report = $itc->daily_sales_summary;
    die("No report filename provided by server\n") unless $report{'filename'};

    my $filename = $config{path}.'/'.$report{'filename'};
    open(OUTFILE, ">$filename") or die("Couldn't open ".$filename);
    print OUTFILE $report{'file'} or die("Couldn't write ".$filename);
    close OUTFILE;
    print 'Wrote file ',$filename, "\n";
    exit;
}

# Otherwise continue on to the database stuff...

sub insertReport
{
    my ($db, $tbname, %report) = @_;
    my @columns = map { "$_=?" } @{$report{'header'}};
    s/[\\\/ ]//g for @columns;  # Elide characters that can't be in column names

    # Reformat dates into something a database can use
    @{$_} = map { (/(\d{2})\/(\d{2})\/(\d{4})/ ? "$3$1$2" : $_) } @{$_} for @{$report{'data'}};

    my $insertSummary = $db->prepare("INSERT INTO $tbname SET ".join(',',@columns));
    $insertSummary->execute(@{$_}) for @{$report{'data'}};
}

# Get the list of dates available from iTC
my @dates = $itc->daily_sales_summary_dates;

my $db = DBI->connect("DBI:$config{driver}:$config{dbname}", $config{dbuser}, $config{dbpass}, {RaiseError=>1});
die("Could not connect to database\n") unless ($db);

# See which dates aren't already in the database
my $dates = join(',', map { "'$_'" } @dates);
my $selectDates = $db->prepare("SELECT DATE_FORMAT(BeginDate,'%m/%d/%Y') FROM dailySalesSummary WHERE DATE_FORMAT(BeginDate,'%m/%d/%Y') IN ($dates) GROUP BY BeginDate ORDER BY BeginDate DESC");
$selectDates->execute;
foreach my $row ( @{$selectDates->fetchall_arrayref} )
{
    @dates = grep { @$row[0] ne $_ } @dates;
}

# For each report that isn't already in the database...
insertReport($db, 'dailySalesSummary', $itc->daily_sales_summary($_)) for @dates;


# --- Update statistics ---

if( scalar @dates )
{
    my $appTable = 'applications';
    # Handle new applications
    my $s = $db->prepare("SELECT dailySalesSummary.VendorIdentifier FROM dailySalesSummary LEFT JOIN $appTable ON dailySalesSummary.VendorIdentifier = $appTable.VendorIdentifier WHERE $appTable.VendorIdentifier is NULL GROUP BY dailySalesSummary.VendorIdentifier");
    if( $s->execute() )
    {
	while( my ($vid) = $s->fetchrow_array() )
	{
	    $db->do("INSERT INTO $appTable (VendorIdentifier,TitleEpisodeSeason) SELECT VendorIdentifier, TitleEpisodeSeason FROM dailySalesSummary WHERE VendorIdentifier='$vid' LIMIT 1");
#	    $db->do("INSERT INTO $appTable (VendorIdentifier,TitleEpisodeSeason,numDays) SELECT VendorIdentifier, TitleEpisodeSeason, COUNT(DISTNCT BeginDate) FROM dailySalesSummary WHERE VendorIdentifier='$vid'");
	}
    }

    # Brute force update. Need to do this better.
    $s = $db->prepare("SELECT VendorIdentifier FROM $appTable");
    if( $s->execute() )
    {
	while( my ($vid) = $s->fetchrow_array() )
	{
	    $db->do("UPDATE $appTable SET numDays=(SELECT COUNT(DISTINCT BeginDate) FROM dailySalesSummary WHERE VendorIdentifier='$vid') WHERE VendorIdentifier='$vid'");
	    $db->do("UPDATE $appTable SET numSales=(SELECT SUM(Units) FROM dailySalesSummary WHERE VendorIdentifier='$vid' AND ProductTypeIdentifier=1) WHERE VendorIdentifier='$vid'");
	    $db->do("UPDATE $appTable SET numUpdates=(SELECT SUM(Units) FROM dailySalesSummary WHERE VendorIdentifier='$vid' AND ProductTypeIdentifier=7) WHERE VendorIdentifier='$vid'");
	    $db->do("UPDATE $appTable SET avgDailySales=(numSales/numDays), avgDailyUpdates=(numUpdates/numDays) WHERE VendorIdentifier='$vid'");
	}
    }
}


# --- Fetch the weekly summaries ---

# Get the list of dates available from iTC
my @dates = $itc->weekly_sales_summary_dates;

# See which reports aren't already in the database
my $dates = join(',', map { "'$_->{To}'" } @dates);
my $selectDates = $db->prepare("SELECT DATE_FORMAT(EndDate,'%m/%d/%Y') FROM weeklySalesSummary WHERE DATE_FORMAT(EndDate,'%m/%d/%Y') IN ($dates) GROUP BY EndDate ORDER BY EndDate DESC");
$selectDates->execute;
foreach my $row ( @{$selectDates->fetchall_arrayref} )
{
    @dates = grep { @$row[0] ne $_->{To} } @dates;
}

# For each report that isn't already in the database...
insertReport($db, 'weeklySalesSummary', $itc->weekly_sales_summary($_->{To})) for @dates;

# --- Fetch the monthly financial reports ---

# Get a list of available reports and compare it against the database
my $list = $itc->financial_report_list;

# See which reports aren't already in the database
my @dates = keys %$list;
my $rid = join(',', map { "'$_'" } @dates);
my $selectDates = $db->prepare("SELECT ReportID FROM FinancialReport WHERE ReportID IN ($rid) GROUP BY ReportID ORDER BY ReportID DESC");
$selectDates->execute;
foreach my $row ( @{$selectDates->fetchall_arrayref} )
{
    @dates = grep { @$row[0] ne $_ } @dates;
}

for my $date ( @dates )
{
    my %reports = $itc->financial_report($date);
    for my $month ( keys %reports )
    {
	for my $region ( keys %{$reports{$month}} )
	{
	    my @columns = map {"$_=?"} ('ReportID', 'RegionCode', @{$reports{$month}{$region}{'header'}});
	    s/[\\\/\s-]//g for @columns;   # Elide characters that can't be in column names

	    my $insertFinancialReport = $db->prepare("INSERT INTO FinancialReport SET ".join(',',@columns));
	    $reports{$month}{$region}{'filename'} =~ /_(\d\d)(\d\d)_(\w\w)\.txt/;
	    $insertFinancialReport->execute('20'.$2.$1, $3, @{$_}) for @{$reports{$month}{$region}{'data'}};
	}
    }
}
