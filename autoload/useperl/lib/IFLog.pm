#! /usr/bin/env perl
package IFLog;
use strict;
use warnings;

my $rootdir = $ENV{HOME};
my $logfile = 'log';
my $fh_log;

# log flag: -1 not open file, 0 not print log, 1 print log
my $logon = main::GetVimVariable('g:ifperl_log_on', -1)
if ($logon >= 0) {
	eval {
		$rootdir = VIM::Eval('useperl#plugin#dir()');
		$logfile = "$rootdir/ifperl.log";
		open($fh_log, '>>', $logfile);
	
		my $fh_old = select($fh_log);
		$|++;
		select($fh_old);
	};
	$logon = -1 if $@;
}

END {close $fh_log;}

# log api
sub send
{
	return unless $logon > 0;
	my ($msg) = @_;
	print $fh_log $msg, "\n";
}

