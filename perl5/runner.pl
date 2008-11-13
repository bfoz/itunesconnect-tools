#! /usr/bin/perl

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
    die;
}

my %options;
getopt('updtDUP', \%options) or usage();

my $user = $options{u} ? $options{u} : undef;
my $password = $options{p} ? $options{p} : undef;
my $dbname = $options{d} ? $options{d} : 'iTunesConnect';
my $dbuser = $options{U} ? $options{U} : 'root';
my $dbpass = $options{P} ? $options{P} : undef;
my $tbname = $options{t} ? $options{t} : 'dailySalesSummary';
my $driver = $options{D} ? $options{D} : 'mysql';

die "Need iTunes username and password\n" unless $user and $password;
my $itc = iTunesConnect->new(user=>$user, password=>$password);

my %report = $itc->daily_sales_summary;

my $db = DBI->connect("DBI:$driver:$dbname", $dbuser, $dbpass, {RaiseError=>1});
die("Could not connect to database\n") unless ($db);

my @columns;
push @columns, "$_=?" for @{$report{'header'}};
s/[\\\/ ]//g for @columns;  # Elide characters that can't be in column names

my $insertSummary = $db->prepare("INSERT INTO $tbname SET ".join(',',@columns));
$insertSummary->execute(@{$_}) for @{$report{'data'}};
