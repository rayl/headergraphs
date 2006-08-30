
use 5.6.0;
use strict;
use warnings;


package Report;

sub header
{
	print "\n\n==========================\n  $_[0]\n==========================\n";
}

sub report_includes
{
	my ($g) = @_;

	header "Includes";
	for my $x ($g->nodes)
	  {
		print "$x:\n";
		print "\t$_\n" for $g->children($x);
	  }
}

sub report_included
{
	my ($g) = @_;

	header "Included by";
	for my $x ($g->nodes)
	  {
		print "$x:\n";
		print "\t$_\n" for $g->parents($x);
	  }
}

my $by_edge_hash;
my $graph;

sub by_total
{
	$by_edge_hash->{$a} <=> $by_edge_hash->{$b} ||
	$a cmp $b;
}

sub by_unique
{
	$graph->unique_tsize($a) <=> $graph->unique_tsize($b) ||
	$a cmp $b;
}

sub report1
{
	my ($a) = @_;
	my ($g, $file, $mesh, $cuts) = ($a->{'graph'}, $a->{'file'}, $a->{'mesh'}, $a->{'cuts'});
	my $total = $g->total_tsize($file);
	$by_edge_hash = $total;
	$graph = $g;
	for my $e (sort by_total keys %$mesh)
	  {
		my $t = $total->{$e} || "?";
		my $n = $g->unique_tsize($e);
		print "\t$t\t$e ($n)\n";
	  }
}

sub report2
{
	my ($a) = @_;
	my ($g, $file, $mesh, $cuts) = ($a->{'graph'}, $a->{'file'}, $a->{'mesh'}, $a->{'cuts'});
	my $total = $g->total_tsize($file);
	$by_edge_hash = $total;
	$graph = $g;
	for my $e (sort by_unique keys %$mesh)
	  {
		my $t = $total->{$e} || "?";
		my $n = $g->unique_tsize($e);
		print "\t$n\t$e ($t)\n";
	  }
}

1;
