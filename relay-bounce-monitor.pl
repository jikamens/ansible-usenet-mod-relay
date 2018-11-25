#!/usr/bin/perl

# Check for bouncing moderator relay addresses.
#
# 1. Parse logs for successful and failed deliveries.
#    - Count successful deliveries by address.
#    - Filter out transient or message-specific failures (e.g., spam
#      bounces). 
#    - Count failed deliveries by address and track the most recent
#      faliure timestamp for each address.
# 2. Read timestamp file to determine when last report was generated.
# 3. Report total number of failures and successes for all addresses
#    which have bounced since the last report, sorted in increasing
#    order by number of successes and decreasing order by number of
#    faliures.
# 4. Report total number of failures and successes for all addresses
#    which have not bounced since the last report, sorted in the same
#    way.
# 5. At the bottom, show up to ten most recent failure log messages
#    for each address, sorted alphabetically by address.
# 6. Store the timestamp for next time.

use strict;
use warnings;

use Date::Parse;
use File::Basename;
use Getopt::Long;

my $whoami = basename $0;
my $time_file = "/var/lib/relay-bounce-monitor.stamp";
my $usage = "Usage: $whoami [--since datetime] [--preserve]\n
    --since Overrides the last report time in $time_file
    --preserve Prevents saving a new last report time";
my $log_limit = 10;

my(%successes, %failures, %logs, %latest_failure, $last_report,
   $preserve, $latest_timestamp);

die $usage if (! GetOptions("--since=s" => \$last_report,
			    "--preserve" => \$preserve));

if ($last_report) {
    die "$whoami: Illegal datetime \"$last_report\"\n$usage"
	if (! str2time($last_report));
    $last_report = str2time($last_report);
}

@ARGV = &find_log_files();
while (<>) {
    next if (! /orig_to=<([^>]+-[^>]+)\@moderators/);
    my $address = $1;
    my $stamp = &parse_syslog_time($_);
    next if (! $stamp);
    $latest_timestamp = $stamp;
    if (/status=sent/) {
        if (! /<mod-bounce\./) {
            $successes{$address}++;
        }
	next;
    }
    $successes{$address} ||= 0;
    next if (/status=deferred/);
    next if (/Blocked\ by\ SpamAssassin|rejected\ due\ to\ spam\ URL|
	     has\ a\ poor\ reputation\ on\ Cloudmark|[Ss]pamhaus|
	     Greylisted|please\ retry\ in\ a\ bit|Infected\ with|
	     spam\ score\ exceeded|cmuScsDiscardSpam|
	     Message\ contained\ unsafe\ content|spam\ message\ rejected|
	     This\ message\ was\ blocked\ because\ its\ content|
             Domain\ Blacklist:\ DBL\ lookup|message\ looks\ like\ spam/x);
    # I use this when looking for new permanent failure messages, but normally
    # it should be commented out because otherwise the script won't ever report
    # anything!
    # next if (/Host\ not\ found|User\ unknown|Recipient\ not\ found|
    # 	     No\ route\ to\ host|Domain\ not\ found|Invalid\ Recipient|
    # 	     No\ Redirect\ Entry\ for\ this\ address|
    # 	     Recipient\ address\ rejected|Host\ found\ but\ no\ data|
    # 	     This\ account\ is\ not\ allowed|account\ expired|
    # 	     This\ user\ doesn't\ have\ a\ (?:aol|geocities)\.com\ account|
    # 	     No\ Such\ User|[Aa]ddressee\ unknown|User\ not\ known|
    # 	     The\ email\ account\ that\ you\ tried\ to\ reach\ does\ not|
    # 	     Email\ address\ could\ not\ be\ found|No\ such\ user|
    # 	     unknown\ or\ illegal\ alias|no\ such\ address\ here|
    # 	     No\ account\ by\ that\ name/x);
    $failures{$address}++;
    $latest_failure{$address} = $stamp;
    unshift(@{$logs{$address}}, $_);
    if (@{$logs{$address}} > $log_limit) {
	@{$logs{$address}} = @{$logs{$address}}[0..$log_limit-1];
    }
}

if (! $last_report) {
    (open(TIME, "<", $time_file) and ($last_report = <TIME>) and
     close(TIME)) or
	$last_report = 0;
    chomp $last_report;
}

my(@addresses) = sort { (($successes{$a} <=> $successes{$b}) or
			 ($failures{$b} <=> $failures{$a})) } keys %failures;
my(@new_addresses) = grep($latest_failure{$_} > $last_report, @addresses);
my(@old_addresses) = grep($latest_failure{$_} <= $last_report, @addresses);

if (@new_addresses) {
    print "New failing addresses:\n\n";
    &report(@new_addresses);

    if (@old_addresses) {
	print "\nOld failing addresses:\n\n";
	&report(@old_addresses);
    }

    foreach my $address (sort keys %logs) {
	print "\n$address:\n\n", @{$logs{$address}};
    }
}

if ($latest_timestamp and ! $preserve) {
    die("$whoami: Failed to save report time to $time_file: $!\n")
	if (! (open(TIME, ">". $time_file) and
	       print(TIME "$latest_timestamp\n")
	       and close(TIME)));
}

sub report {
    my(@addresses) = @_;
    my $format = "%-56s %9s %10s\n";
    printf($format, "Address", "#failures", "#successes");
    printf($format, "-------", "---------", "----------");
    foreach my $address (@addresses) {
	printf($format, $address, $failures{$address},
	       ($successes{$address} or 0));
    }
}

sub parse_syslog_time {
    local($_) = @_;
    return 0 if (! /^(... .. ..:..:..)/);
    my($date_string) = $1;
    my $stamp = str2time($date_string);
    if ($stamp > time) {
	$date_string .= " " . (localtime(time))[5] + 1900 - 1;
	return str2time($date_string);
    }
    return $stamp;
}

sub find_log_files {
    my(@date_files) = glob("/var/log/maillog-2[0-9]*");
    my(@numbered_files) = (glob("/var/log/mail.log.[0-9]"),
			   glob("/var/log/mail.log.[0-9].*"));
    my(@current_files) = grep(-f $_, "/var/log/maillog", "/var/log/mail.log");
    my(@files);
    foreach my $file (@date_files, reverse sort @numbered_files,
		      @current_files) {
	if ($file =~ /\.gz$/) {
	    push(@files, "gunzip < $file|");
	}
	elsif ($file =~ /\.bz2$/) {
	    push(@files, "bunzip2 < $file|");
	}
	else {
	    push(@files, $file);
	}
    }
    return(@files);
}

    
