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

#
#  Dot.pm - Display an Analysis object using the 'dot' language
#

use 5.6.0;
use strict;
use warnings;

package Dot2;

#
# a set of unique tsizes for "backbone" and "heavy" determination
# and for color saturation calculation.
#
my @threshold = (100, 200, 300, 500);

#
# Decide whether a node is "backbone" or not, based on the unique
# tsize.
#
sub backbone
{
	my ($weight) = @_;
	$weight >= $threshold[0];
}

#
# Decide whether a node is "heavy" or not, based on the unique
# tsize.
#
sub heavy
{
	my ($weight) = @_;
	$weight >= $threshold[2];
}

#
# Nodes are colored yellow, red or blue if they have sufficiently
# large unique tsize.  The saturation of the color rises with
# increasing unique tsize.
#
sub saturation
{
	my ($weight) = @_;
	if     ($weight < $threshold[0]) { "c0" }
	elsif  ($weight < $threshold[1]) { "90" }
	elsif  ($weight < $threshold[2]) { "60" }
	elsif  ($weight < $threshold[3]) { "30" }
	else                             { "00" }
}

#
# Backbone nodes are yellowish.
#
sub backbone_color
{
	my ($weight) = @_;
	my $c = saturation($weight);
	"#ffff${c}";
}

#
# Heavy nodes are reddish.
#
sub heavy_color
{
	my ($weight) = @_;
	my $c = saturation($weight);
	"#ff${c}${c}";
}

#
# Decide whether an edge to the target node should be snipped in
# order to relax the graph.
#
sub should_snip
{
	my ($a, $source, $target) = @_;

	# snip the edge if this source file is included from
	# too many other header files
	return 1 if $a->{'hfiles'}->{$source} > 4;

	# otherwise, keep the edge
	return 0;
}

sub print_node
{
	my ($a, $node, $snipped) = @_;

	my $g = $a->{'graph'};

	my $t = $a->{'cfiles'}->{$node} || 0;
	my $h = $a->{'hfiles'}->{$node} || 0;
	my $n = $g->upsize($node);

	my $fill = ($node eq $a->{'file'})  ? "#ff8080"          :
	           heavy($n)                ? heavy_color($n)    :
	           backbone($n)             ? backbone_color($n) :
	                                      "#c0ffc0";
	my $shape = "ellipse";
	my $snips = "";

	if (exists $snipped->{$node})
	  {
		$shape = "box";

		$snips .= "\\n~~~";

		for my $source (@{$snipped->{$node}})
		  {
			my $t2 = $a->{'cfiles'}->{$source} || 0;
			my $h2 = $a->{'hfiles'}->{$source} || 0;
			my $n2 = $g->upsize($source);
			$snips .= "\\n$source  $t2 - $h2 - $n2";
		  }
	  }

	print "\t\"$node\" [label=\"${node}\\n${t} - ${h} - ${n}${snips}\",shape=${shape},fillcolor=\"${fill}\",style=filled];\n";
}

#
# Print all nodes
#
sub print_nodes
{
	my ($a, $snipped) = @_;

	for my $node (keys %{$a->{'nodelist'}})
	  {
		if ($node ne $a->{'file'})
		  {
			print_node($a, $node, $snipped);
		  }
	  }
}

#
# Print the root node(s).
#
sub print_root
{
	my ($a, $roots) = @_;

	my $node = $a->{'file'};

	my $g = $a->{'graph'};

	my $t = $a->{'cfiles'}->{$node} || 0;
	my $h = $a->{'hfiles'}->{$node} || 0;
	my $n = $g->upsize($node);

	my $fill = "#ff8000";
	my $shape = "house";

	print "\t\"$node\" [label=\"${node}\\n${t} - ${h} - ${n}\",shape=${shape},fillcolor=\"${fill}\",style=filled];\n";

	for (; $roots != 0; $roots--)
	  {
		print "\t\"$node/$roots\" [label=\"*\",shape=circle,fillcolor=\"#ff8000\",style=filled];\n";
	  }
}

#
# Print a single edge.
#
sub print_edge
{
	my ($a, $source, $target, $snipped, $roots) = @_;

	# check whether this edge to the target node should be snipped or not.
	if ((defined $roots) && ($source eq $a->{'file'}))
	  {
		# increment the number of virtual root nodes to generate
		${$roots}++;

		# generate an edge from the virtual root node
		print "\t\"$target\" -> \"$source/${$roots}\";\n";
	  }
	elsif (should_snip($a, $source, $target))
	  {
		# if so, add source to the cluster for this target
		$snipped->{$target} ||= [];
		push @{$snipped->{$target}}, $source;
	  }
	else
	  {
		# if not, generate the edge
		print "\t\"$target\" -> \"$source\";\n";
	  }
}

#
# Print all edges.
#
sub print_edges
{
	my ($a, $snipped) = @_;
	my $mesh = $a->{'mesh'};

	# only generate virtual roots if we have > 3 child on root node
	my $roots;
	if (scalar keys %{$mesh->{$a->{'file'}}} > 3) 
	  {
		my $x;
		$roots = \$x;
	  }

	# walk over each source node
	for my $source (sort keys %$mesh)
	  {
		# walk over each target node for this source
		for my $target (keys %{$mesh->{$source}})
		  {
			print_edge($a, $source, $target, $snipped, $roots);
		  }
	  }

	# return the number of virtual root nodes to generate
	(defined $roots) ? $$roots : 0;
}

#
# Print the graph header.
#
sub print_ghead
{
	my ($a) = @_;
	my $file = $a->{'file'};
	print "digraph \"$file\" {\n";
	print "\toverlap=false;\n";
	print "\tsplines=true;\n";
	print "\troot=\"$file\";\n";
}

#
# Print the graph footer.
#
sub print_gfoot
{
	my ($a) = @_;
	print "}\n";
}

#
# Generate a dot graph.
#
# The input is an analysis object, which has extracted some
# useful bits of information about the topology of an
# underlying graph object.
#
sub graph2
{
	my ($a) = @_;
	my %snipped;
	print_ghead($a);
	my $roots = print_edges($a, \%snipped);
	print_nodes($a, \%snipped);
	print_root($a, $roots);
	print_gfoot($a);
}

1;
