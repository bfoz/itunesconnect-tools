#! /usr/bin/perl
# $Id: runner.pl,v 1.6 2008/11/21 20:37:32 bfoz Exp $

use WWW::iTunesConnect;
use DBI;
use Getopt::Std;

sub usage
{
    print "./runner.pl [options]\n";
    print "    -u user	iTunes Connect username\n";
    print "    -p pass	iTunes Connect password\n";
    print "    -d dbname	Database name\n";
    print "    -t tbname	Daily summary table name\n";
    print "    -D driver	Database driver (mysql, ...)\n";
    print "    -U user	Database username\n";
    print "    -P pass	Database password\n";
    print "    -s dir	Save reports to dir instead of to a table\n";
    die;
}

my %options;
getopts('u:p:d:t:D:U:P:s:', \%options) or usage();

my $user = $options{u} ? $options{u} : undef;
my $password = $options{p} ? $options{p} : undef;
my $dbname = $options{d} ? $options{d} : 'iTunesConnect';
my $dbuser = $options{U} ? $options{U} : 'root';
my $dbpass = $options{P} ? $options{P} : undef;
my $tbname = $options{t} ? $options{t} : 'dailySalesSummary';
my $driver = $options{D} ? $options{D} : 'mysql';
my $path = $options{s} ? $options{s} : undef;

die "Need iTunes username and password\n" unless $user and $password;
my $itc = WWW::iTunesConnect->new(user=>$user, password=>$password);

my %report = $itc->daily_sales_summary;

if( $path and $report{'filename'} )
{
    my $filename = $path.'/'.$report{'filename'};
    open(OUTFILE, ">$filename") or die("Couldn't open ".$filename);
    print OUTFILE $report{'file'} or die("Couldn't write ".$filename);
    close OUTFILE;
    print 'Wrote file ',$filename, "\n";
    exit;
}

my $db = DBI->connect("DBI:$driver:$dbname", $dbuser, $dbpass, {RaiseError=>1});
die("Could not connect to database\n") unless ($db);

my @columns;
push @columns, "$_=?" for @{$report{'header'}};
s/[\\\/ ]//g for @columns;  # Elide characters that can't be in column names

# Reformat dates into something a database can use
@{$_} = map { (/(\d{2})\/(\d{2})\/(\d{4})/ ? "$3$1$2" : $_) } @{$_} for @{$report{'data'}};

my $insertSummary = $db->prepare("INSERT INTO $tbname SET ".join(',',@columns));
$insertSummary->execute(@{$_}) for @{$report{'data'}};

my $appTable = 'applications';

# Handle new applications
my $s = $db->prepare("SELECT $tbname.VendorIdentifier FROM $tbname LEFT JOIN $appTable ON $tbname.VendorIdentifier = $appTable.VendorIdentifier WHERE $appTable.VendorIdentifier is NULL GROUP BY $tbname.VendorIdentifier");
if( $s->execute() )
{
    while( my ($vid) = $s->fetchrow_array() )
    {
	$db->do("INSERT INTO $appTable (VendorIdentifier,TitleEpisodeSeason) SELECT VendorIdentifier, TitleEpisodeSeason FROM dailySalesSummary WHERE VendorIdentifier='$vid' LIMIT 1");
#	$db->do("INSERT INTO $appTable (VendorIdentifier,TitleEpisodeSeason,numDays) SELECT VendorIdentifier, TitleEpisodeSeason, COUNT(DISTNCT BeginDate) FROM dailySalesSummary WHERE VendorIdentifier='$vid'");
    }
}

# Brute force update. Need to do this better.
$s = $db->prepare("SELECT VendorIdentifier FROM $appTable");
if( $s->execute() )
{
    while( my ($vid) = $s->fetchrow_array() )
    {
	$db->do("UPDATE $appTable SET numDays=(SELECT COUNT(DISTINCT BeginDate) FROM $tbname WHERE VendorIdentifier='$vid') WHERE VendorIdentifier='$vid'");
	$db->do("UPDATE $appTable SET numSales=(SELECT SUM(Units) FROM $tbname WHERE VendorIdentifier='$vid' AND ProductTypeIdentifier=1) WHERE VendorIdentifier='$vid'");
	$db->do("UPDATE $appTable SET numUpdates=(SELECT SUM(Units) FROM $tbname WHERE VendorIdentifier='$vid' AND ProductTypeIdentifier=7) WHERE VendorIdentifier='$vid'");
	$db->do("UPDATE $appTable SET avgDailySales=(numSales/numDays), avgDailyUpdates=(numUpdates/numDays) WHERE VendorIdentifier='$vid'");
    }
}
