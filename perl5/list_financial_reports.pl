#! /usr/bin/perl

use WWW::iTunesConnect;
use Getopt::Std;

sub usage
{
    print "./fetch_all_financial_reports.pl [options]\n";
    print "    -u user	iTunes Connect username\n";
    print "    -p pass	iTunes Connect password\n";
    print "    -c path	Path to config file (defaults to ./config.pl)\n";
    die;
}

# Default configuration options
my %config = (	'user' => undef,
		'password' => undef,
		'config' => 'config.pl');

# Parse the command line options
my %options;
getopts('u:p:c:', \%options) or usage();

# Handle -c early so the default config file path can be overriden
$config{config} = $options{c} if $options{c};
delete $options{config};	# Don't need this one any more

# Config file overrides defaults
my %in = do $config{config};
@config{keys %in} = values %in;

my %opt2config = (  'u' => 'user',
                    'p' => 'password',
                 );

# Command line options override defaults and config.pl
@config{@opt2config{keys %options}} = values %options;

die "Need iTunes username and password\n" unless $config{user} and $config{password};
my $itc = WWW::iTunesConnect->new(user=>$config{user}, password=>$config{password});

print "Attempting login with user <", $config{user}, ">\t";
print (($itc->login) ? "SUCCESS\n" : "FAIL\n");

my %list = %{$itc->financial_report_list};
die "Could not fetch the list of financial reports\n" unless %list;

for my $date ( sort keys %list )
{
    print "$date";
    for my $region ( sort keys %{$list{$date}} )
    {
    	print "\t$region\t";
    	print "\t" if length($region) < 8;
    	print $list{$date}{$region}{filename}, "\n";
    }
}
