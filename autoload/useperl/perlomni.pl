#! /usr/bin/env perl
# let perlomni.vim make use of if_perl feature
package perlomni;
use strict;
use warnings;

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
		if( /(\$\w+)\s*=\s*new\s+([A-Z][a-zA-Z0-9_:]+)/  ) {
			print $1 , "\t" , $2 , "\n";
		}
		elsif( /(\$\w+)\s*=\s*([A-Z][a-zA-Z0-9_:]+)->new/  ) {
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
		if( $val =~ /(\$\w+)\s*=\s*new\s+([A-Z][a-zA-Z0-9_:]+)/  ) {
			print "$1 $2\n";
		}
		elsif( $val =~ /(\$\w+)\s*=\s*([A-Z][a-zA-Z0-9_:]+)->new/  ) {
			print "$1 $2\n";
		}
	}
}

1;
__END__
