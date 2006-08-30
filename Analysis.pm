
use 5.6.0;
use strict;
use warnings;

package Analysis;


sub collect_children
{
	my ($g, $file, $n, $edges, $visiting) = @_;
	return if $n == 0;
	return if $visiting->{$file};
	$edges->{$file} ||= {};
	$visiting->{$file} = 1;
	for my $e ($g->children($file))
	  {
		$edges->{$file}->{$e}++;
		collect_children($g, $e, $n-1, $edges, $visiting);
	  }
	delete $visiting->{$file};
}

sub collect_parents
{
	my ($g, $file, $n, $edges, $visiting) = @_;
	return if $n == 0;
	return if $visiting->{$file};
	$visiting->{$file} = 1;
	for my $e ($g->parents($file))
	  {
		$edges->{$e} ||= {};
		next if $edges->{$e}->{$file};
		$edges->{$e}->{$file} = 1;
		collect_parents($g, $e, $n-1, $edges, $visiting);
	  }
	delete $visiting->{$file};
}

sub extract
{
	my ($g, $file, $clevel, $plevel) = @_;
	my $x = {};
	collect_children($g, $file, $clevel, $x, {});
	collect_parents($g, $file, $plevel, $x, {});
	$x;
}

sub snip
{
	my ($g, $file, $many, $mesh) = @_;
	my %m = map {$_ => 0} @{$g->too_many($file, $many)};
	map {$m{$_}++ if exists $m{$_}} map {keys %{$mesh->{$_}}} sort keys %$mesh;
	\%m;
}

sub analyse
{
	my ($g, $file, $clevel, $plevel, $count) = @_;
	my ($mesh) = extract($g, $file, $clevel, $plevel);
	my $cuts = snip($g, $file, $count, $mesh);
	($file, $mesh, $cuts, $g->total_tsize($file));
}

1;
