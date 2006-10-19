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
	$by_edge_hash->{$b} <=> $by_edge_hash->{$a} ||
	$a cmp $b;
}

sub by_unique
{
	$graph->ucsize($b) <=> $graph->ucsize($a) ||
	$a cmp $b;
}

sub by_name
{
	$a cmp $b;
}

my ($e, $n, $t);

format fmt =
     @>>>> - @<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< 
     $n, $t, $e
.
sub do_report
{
	my ($a, $func) = @_;
	my ($g, $file, $mesh) = ($a->{'graph'}, $a->{'file'}, $a->{'mesh'});
	my $total = $g->tcsize($file);
	$by_edge_hash = $total;
	$graph = $g;
	$~ = "fmt";
	print "\n    Unique - Total      Filename\n";
	for my $z (sort $func keys %$mesh)
	  {
		$e = $z;
		$t = $total->{$e} || "?";
		$n = $g->ucsize($e);
		#print "\t$e $n - $t\n";
		write;
	  }
}

sub total
{
	do_report(shift, \&by_total);
}

sub unique
{
	do_report(shift, \&by_unique);
}

sub name
{
	do_report(shift, \&by_name);
}

1;
