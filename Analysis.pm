
use 5.6.0;
use strict;
use warnings;

package Analysis;

sub collect_children
{
	my ($z, $file, $n, $visiting) = @_;
	return if $n == 0;
	return if $visiting->{$file};
	$z->{'mesh'}->{$file} ||= {};
	$visiting->{$file} = 1;
	for my $e ($z->{'graph'}->children($file))
	  {
		$z->{'mesh'}->{$file}->{$e}++;
		$z->collect_children($e, $n-1, $visiting);
	  }
	delete $visiting->{$file};
}

sub collect_parents
{
	my ($z, $file, $n, $visiting) = @_;
	return if $n == 0;
	return if $visiting->{$file};
	$visiting->{$file} = 1;
	for my $e ($z->{'graph'}->parents($file))
	  {
		$z->{'mesh'}->{$e} ||= {};
		next if $z->{'mesh'}->{$e}->{$file};
		$z->{'mesh'}->{$e}->{$file} = 1;
		$z->collect_parents($e, $n-1, $visiting);
	  }
	delete $visiting->{$file};
}

sub snip
{
	my ($z, $mesh) = @_;
	my %m = map {$_ => 0} @{$z->{'graph'}->too_many($z->{'file'}, $z->{'many'})};
	map {$m{$_}++ if exists $m{$_}} map {keys %{$z->{'mesh'}->{$_}}} sort keys %{$z->{'mesh'}};
	$z->{'cuts'} = \%m;
}

sub new
{
	my ($type, $g, $file, $clevel, $plevel, $many) = @_;

	# analysis objects use a hash representation
	my $z = bless {}, ref $type || $type;

	# save the parms for this analysis
	$z->{'graph'} = $g;
	$z->{'file'} = $file;
	$z->{'clevel'} = $clevel;
	$z->{'plevel'} = $plevel;
	$z->{'many'} = $many;

	# perform the analysis
	$z->{'mesh'} = {};
	$z->collect_children($file, $clevel, {});
	$z->collect_parents($file, $plevel, {});
	$z->snip;

	# return the new object
	$z;
}

1;
