#! /usr/bin/perl

use WWW::iTunesConnect;
use Getopt::Long;

sub usage
{
    print "./financial_reports.pl [options]\n";
    print "    -u user	iTunes Connect username\n";
    print "    -p pass	iTunes Connect password\n";
    print "    -c path	Path to config file (defaults to ./config.pl)\n";
    print "    --asc	Sort reports by date (ascending)\n";
    print "    --desc	Sort reports by date (descending, default)\n";
    print "    --save dir	Save the reports to the given directory\n";
    print "    --total	Display report totals\n";
    die;
}

my %config;	# Configuration options

# Parse the command line options
my %options = ( 'config' => 'config.pl');
GetOptions(\%options, 'user|u=s', 'password|p=s', 'config|c=s',
		      'asc' => sub { $options{'sort'} = 1; },
		      'desc' => sub { $options{'sort'} = 0; },
		      'save=s', 'total');

# Handle the config path early so the default config file path can be overriden
$config{'config'} = $options{'config'} if $options{'config'};
delete $options{'config'};	# Don't need this one any more

# Config file overrides defaults
my %in = do $config{config};
@config{keys %in} = values %in;

# Command line options override defaults and config.pl
@config{keys %options} = values %options;

# Post-process the command line arguments
if( exists $config{'save'} )
{
    use File::Slurp;
    unless( -d $config{'save'} )
    {
	use File::Path;
	mkpath($config{'save'});
    }
}

$config{'fetch'} = 1 if exists $config{'total'} or exists $config{'save'};


die "Need iTunes username and password\n" unless $config{user} and $config{password};
my $itc = WWW::iTunesConnect->new(user=>$config{user}, password=>$config{password});

print "Attempting login with user <", $config{user}, ">\t";
print (($itc->login) ? "SUCCESS\n" : "FAIL\n");

my %list = %{$itc->financial_report_list};
die "Could not fetch the list of financial reports\n" unless %list;

my %grand_totals;
for my $date ( sort { $options{'sort'} ? ($a cmp $b) : ($b cmp $a) } keys %list )
{
    print "$date";
    for my $region ( sort keys %{$list{$date}} )
    {
    	print "\t$region\t";
    	print "\t" if length($region) < 8;

	# Fetch the report if needed
	my %report;
	if( exists $config{'fetch'} )
	{
	    %report = $itc->fetch_financial_report($date, $region);
	    next unless %report;
	}

	# Handle the --save command
	if( exists $config{'save'} )
	{
	    write_file($config{'save'}.'/'.$list{$date}{$region}{'filename'}, $report{'content'});
	}

	if( exists $config{'total'} )
	{
	    # Parse the data
	    my %parsed = WWW::iTunesConnect::parse_financial_report($report{'content'});
	    next unless %parsed;

	    my %totals;
	    for my $row ( @{$parsed{'data'}} )
	    {
		my $eps = @$row[7];		# Extended Parner Share
		my $currency = @$row[8];	# Parner Share Currency
		$totals{$currency} = 0 unless exists $totals{$currency};
		$totals{$currency} += $eps;
		$grand_totals{$currency} = 0 unless exists $grand_totals{$currency};
		$grand_totals{$currency} += $eps;
	    }
	    printf "\t%6.2f %s", $totals{$_}, $_ for keys %totals;
	}
	else
	{
	    print $list{$date}{$region}{filename};
	}
	print "\n";
    }
}

if( exists $config{'total'} )
{
    print "\nTotals";
    printf "\t%6.2f %s\n", $grand_totals{$_}, $_ for sort keys %grand_totals;
}
