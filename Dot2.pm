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
my @threshold = (25, 50, 100, 150);

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
# Target nodes (included many times) have a reddish or yellowish color.
#
sub target_color
{
	my ($weight) = @_;
	my $c = saturation($weight);
	heavy($weight) ? "#ff${c}${c}" : "#ffff${c}";
}

#
# Backbone nodes have a bluish color, non-backbone are green.
#
sub backbone_color
{
	my ($weight) = @_;
	my $c = saturation($weight);
	backbone($weight) ? "#${c}${c}ff" : "#${c}ff${c}";
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

	my $fill = ($node eq $a->{'file'}) ? "#800000" : "#ffffff";
	my $shape = "ellipse";
	my $snips = "";

	if (exists $snipped->{$node})
	  {
		$shape = "box";

		for my $source (@{$snipped->{$node}})
		  {
			$snips .= "$source\\n";
		  }
		$snips .= "~~~\\n";
	  }

	print "\t\"$node\" [label=\"${snips}${node}\\n${t} - ${h}\",shape=${shape},fillcolor=\"${fill}\",style=filled];\n";
}

#
# Print all nodes
#
sub print_nodes
{
	my ($a, $snipped) = @_;

	for my $node (keys %{$a->{'nodelist'}})
	  {
		print_node($a, $node, $snipped);
	  }
}

#
# Print a single edge.
#
sub print_edge
{
	my ($a, $source, $target, $snipped) = @_;

	# check whether this edge to the target node should be snipped or not.
	if (should_snip($a, $source, $target))
	  {
		# if so, add source to the cluster for this target
		$snipped->{$target} ||= [];
		push @{$snipped->{$target}}, $source;
	  }
	else
	  {
		# if not, generate the edge
		print "\t\"$source\" -> \"$target\" [dir=\"back\"];\n";
	  }
}

#
# Print all edges.
#
sub print_edges
{
	my ($a, $snipped) = @_;
	my $mesh = $a->{'mesh'};

	# walk over each source node
	for my $source (sort keys %$mesh)
	  {
		# walk over each target node for this source
		for my $target (keys %{$mesh->{$source}})
		  {
			print_edge($a, $source, $target, $snipped);
		  }
	  }
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
	print_edges($a, \%snipped);
	print_nodes($a, \%snipped);
	print_gfoot($a);
}

1;
