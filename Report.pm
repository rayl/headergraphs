# headergraphs - a tool to visualize header inclusion hierarchies
# Copyright (C) 2006  Ray Lehtiniemi
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License _only_.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


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
