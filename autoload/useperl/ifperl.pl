#! /usr/bin/env perl
# let default main package for vim
# package ifperl;
use strict;
use warnings;
# use VIM;

# check if call from within vim
our $InsideVim = 0;
{
	eval { VIM::Eval(1); };
	$InsideVim = 1 unless $@;
}

#
## GotFuncName
# print string to stdout, which captured by vim

# send a comma-separated list of @INC path
sub GotIncPath
{
	print join(',', @INC);
}

# symbol table of a module, such as PackName::SubName
# NOT inclue prefix PackName::
sub GotModuleSyms
{
	my ($name) = @_;
	my $pack_ref = eval('\%' . $name . '::');
	foreach my $key (sort keys %$pack_ref) {
		next if $key =~ /BEGIN/;
		print "$key\n";
	}
}

# Search by perl regexp in current vim buffer
# print out the matched :line|col string
sub SearchLine
{
	my $pattern = shift;
	return unless $InsideVim;
	
	my $file = $main::curbuf->Name();
	my $lineCount = $main::curbuf->Count();
	foreach my $i (1 .. $lineCount) {
		my $lineStr = $main::curbuf->Get($i);
		# print "$i: $&\n" if $lineStr =~ $pattern;
		if ($lineStr =~ $pattern) {
			my $position = length($`);
			print "$file:$i|$position $&\n";
		}
	}
}

#
## exchange default global variable of three data type
#
sub SetVimVariable
{
	my ($name, $val) = @_;
	$name = single_quote($val);
	VIM::DoCommand("let $name = $val");
}

sub SetVimScalar
{
	my ($val) = @_;
	$val = single_quote($val);
	VIM::DoCommand("let g:useperl#ifperl#scalar = $val");
}

sub SetVimDict
{
	my ($key, $val) = @_;
	$key = single_quote($key);
	$val = single_quote($val);
	VIM::DoCommand("let g:useperl#ifperl#dict[$key] = $val");
}

sub AddVimList
{
	my ($val) = @_;
	$val = single_quote($val);
	VIM::DoCommand("call add(g:useperl#ifperl#list, $val)");
}

sub ToVimList
{
	my ($array_ref) = @_;
	VIM::DoCommand("let g:useperl#ifperl#list = []");
	foreach my $val (@$array_ref) {
		AddVimList($val);
	}
}

sub ToVimDict
{
	my ($hash_ref) = @_;
	VIM::DoCommand("let g:useperl#ifperl#dict = {}");
	foreach my $key (keys %$hash_ref) {
		AddVimList($key, $hash_ref->{$key});
	}
}

sub single_quote
{
	my ($val) = @_;
	$val = "$val";
	if ($val =~ "'") {
		$val =~ s/'/''/g;
	}
	return "'$val'";
}

# return the first buffer object match $arg, or default $curbuf
sub GetBuffer
{
	my ($arg) = @_;
	return $main::curbuf unless $arg;
	my $buf = (VIM::Buffers($arg))[0];
	return $buf;
}

## Test Function:
#

sub Hello
{
	print "hello vim if_perl\n";
	print "hello $_\n" for @_;
}

sub TestIfperl
{
	my ($var) = @_;
	Hello();
	Hello(qw(AAAA BBBB CCCC));
}

TestIfperl() unless caller;
1;
=pod

    :perl require "./ifperl.pl";
    :perl ifperl::Hello();

因为该文件置于 package ifperl 内，不能直接调用 Hello()
采用默认的 main 包就可以。

require 也取决于 perl 的 @INC 搜索路径。可用 uselib 添加搜索路径。
    :perl use lib(".")
=cut
