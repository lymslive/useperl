#! /usr/bin/env perl
# generate module list on local host from @INC
use strict;
use warnings;
use File::Find;
use File::Spec::Functions;

my $CurBase;
my (@modules, @files);

##-- MAIN --##
sub main
{
	my @libs = @_;
	@libs = grep {file_name_is_absolute($_)} @INC unless @libs;
	@modules = ();
	@files = ();
	foreach my $inc (@libs) {
		next unless -d $inc;
		&find_from($inc);
	}
	&output();
}

##-- SUBS --##

my $CurBaseLen = 0;
sub find_from
{
	my ($inc) = @_;
	$CurBase = catfile($inc, ''); # keep tail /
	$CurBaseLen = length($CurBase);
	# warn "find in: $CurBase\n";
	find(\&want_module, ($inc));
}

sub want_module
{
	return unless /\.pm$/;
	my $file = $File::Find::name;
	my $module = substr($file, $CurBaseLen, length($file) - $CurBaseLen - 3);
	# my $module = $file;
	# $module=~ s/^$CurBase//;
	# $module =~ s/\.pm$//;
	$module =~ s|[/\\]|::|g;
	push @modules, $module;
	push @files, $file;
}

sub output
{
	print "=item Module\n";
	print "$_\n" for @modules;
	print "\n";
	print "=item File\n";
	print "$_\n" for @files;
}

##-- END --##
&main(@ARGV) unless defined caller;
1;
__END__
