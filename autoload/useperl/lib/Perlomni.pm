#! /usr/bin/env perl
# let perlomni.vim make use of if_perl feature
package Perlomni;
use strict;
use warnings;

use IFLog;

# $obj = new Class::Module
my $REG_NEW_POST = qr/(\$\w+)\s*=\s*new\s+([A-Z][a-zA-Z0-9_:]+)/;
# $obj = Class::Module->new
my $REG_NEW_ARROW = qr/(\$\w+)\s*=\s*([A-Z][a-zA-Z0-9_:]+)->new/;

# refer to: bin/grep-pattern.pl
sub GrepPattern
{
	my ($file, $pattern) = @_;
	
	open FH, "<" , $file or die $!;
	my @lines = <FH>;
	close FH;

	my @vars = ();
	for ( @lines ) {
		while ( /$pattern/og ) {
			push @vars,$1;
		}
	}
	print $_  . "\n" for @vars;
}

# refer to: bin/grep-objvar.pl
sub GrepObjval
{
	my ($file) = @_;
	
	open FH, "<", $file or die $!;
	my @lines = <FH>;
	close FH;

	for ( @lines ) {
		if( /$REG_NEW_POST/  ) {
			print $1 , "\t" , $2 , "\n";
		}
		elsif( /$REG_NEW_ARROW/  ) {
			print $1 , "\t" , $2 , "\n";
		}
	}
}

# call by ifperl.deal_list()
# extract $1 from pattern, input string is passed by g:useperl#ifperl#list
sub DLGrepPattern
{
	my $pattern = shift or return;
	my ($success, $value) = VIM::Eval('g:useperl#ifperl#list');
	return unless $success && $value;
	foreach my $val (split /\n/, $value) {
		print "$1\n" if $val =~ /$pattern/;
	}
}

# print "$1\t$2" will cause problem within vim, <tab> char become "^I"
sub DLGrepObjval
{
	my ($success, $value) = VIM::Eval('g:useperl#ifperl#list');
	return unless $success && $value;
	foreach my $val (split /\n/, $value) {
		if( $val =~ /$REG_NEW_POST/  ) {
			print "$1 $2\n";
		}
		elsif( $val =~ /$REG_NEW_ARROW/  ) {
			print "$1 $2\n";
		}
	}
}

# scan buffer lines and print out uniq sorted match $1
sub ScanBufUniq
{
	my ($bn, $pattern) = @_;
	my $buf = main::GetBuffer($bn);

	my %result = ();

	my $cnt = $buf->Count();
	for (my $i = 1; $i <= $cnt; $i++) {
		my $line = $buf->Get($i);
		$result{$1}++ if $line =~ /$pattern/;
	}
	
	foreach my $key (sort keys %result) {
		print "$key\n";
	}
}

# scan objvar directorly from buffer
sub ScanBufObjval
{
	my ($bn) = @_;
	my $buf = main::GetBuffer($bn);

	my $cnt = $buf->Count();
	for (my $i = 1; $i <= $cnt; $i++) {
		my $line = $buf->Get($i);
		if( $line =~ /$REG_NEW_POST/  ) {
			print "$1 $2\n";
		}
		elsif( $line =~ /$REG_NEW_ARROW/  ) {
			print "$1 $2\n";
		}
	}
}

# extract the head part, package and use lines, from vim buffer.
# eval in a block to figure out symbol tables.
# print out: package name and @ISA list
# if no package in the buffer, use file name(upper case) instead.
sub SimpPackage
{
	my ($bn) = @_;
	my $buf = main::GetBuffer($bn);

	my $package;
	my @code = ();

	my $cnt = $buf->Count();
	for (my $i = 1; $i <= $cnt; $i++) {
		my $line = $buf->Get($i);
		next if $line =~ /^\s*#/;
		push @code, $line if $line =~ /^\s*(package)/;
		push @code, $line if $line =~ /^\s*(use|require|extend)/;
		$package = $1 if $line =~ /^\s*package\s+(\w+)\s*;/;
	}

	unless ($package) {
		my $file = $buf->Name();
		$file =~ s/\..*$//g;
		$package = uc($file);
		my $line = "package $package;\n";
		unshift @code, $line;
	}
	# IFLog::send($package);
	
	my $code = join("\n", @code);
	$code = "{\n$code\n}\n1;";
	# IFLog::send($code);
	eval($code);

	print "$package";
	my @isa = eval('@' . $package . '::ISA');
	if (@isa) {
		print ' < ';
		print join(' ', @isa);
	}
}
1;
__END__
