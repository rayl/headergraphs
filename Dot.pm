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

package Dot;

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
	my $cuts = $a->{'cuts'};

	# we should not snip this edge unless the target has "too many"
	# incoming edges
	return 0 unless exists $cuts->{$target};

	# this target has lots of incoming edges, but we always want the one
	# with the largest unique tsize to reamin intact, no matter what.
	# this avoids disconnected subtrees floating over to the right side
	# of the page.
	return 0 if $cuts->{$target}->[0] eq $source;

	# this is one of the less important links to the target. we prefer to
	# snip these edges unless the target is a part of the backbone.  in
	# that case, we'd like this "primary hierarchy" to remain contiguous
	# on the graph
	my $weight = $a->{'graph'}->unique_tsize($target);
	return 1 unless backbone($weight);

	# this node is part of the blue backbone.  if there are less than 3
	# incoming edges, we want to keep things contiguous.
	return 0 if scalar @{$cuts->{$target}} < 3;

	# the node is part of the backbone, but has too many incoming edges
	# to keep everything contiguous while maintaining a clean layout.
	# we know it's not the heaviest incoming edge, so check next one and
	# keep it, snipping the rest.
	return 0 if $cuts->{$target}->[1] eq $source;
	return 1;
}

sub print_node
{
	my ($a, $node, $snipped) = @_;

	my $g = $a->{'graph'};
	my $t = $g->total_tsize($a->{'file'})->{$node} || "?";
	my $n = $g->unique_tsize($node);
	my $listing = "";
	my $shape;

	# if we are printing a node with trimmed outgoing edges
	if (exists $snipped->{$node})
	  {
		$shape = "box";

		# generate the list of snipped headers
		$listing = "\\n~\\n";
		for my $target (@{$snipped->{$node}})
		  {
			my $xx = scalar @{$a->{'cuts'}->{$target}};
			my $tt = $g->total_tsize($a->{'file'})->{$target} || "?";
			my $nn = $g->unique_tsize($target);
			$listing .= "$target $nn - $tt - $xx\\n";
		  }
	  }

	# if we are printing the root node for this analysis, make it into an orange house shape
	if ($node eq $a->{'file'})
	  {
		$shape ||= "house";
		print "\t\"$node\" [label=\"$node\\n$n - $t$listing\", shape=$shape, color=\"#000000\", fillcolor=\"#ff8000\", style=filled];\n";
	  }


	# if we are printing a node with many incoming edges...
	elsif (exists $a->{'cuts'}->{$node})
	  {
		my $x = scalar @{$a->{'cuts'}->{$node}};

		$shape ||= "ellipse";

		my $o = target_color($n);

		# print the node, mentioning how many times it is included
		print "\t\"$node\" [label=\"$node\\n$n - $t - $x$listing\",shape=$shape,fillcolor=\"$o\",style=filled];\n";
	  }

	# if we are printing an ordinary node
	else
	  {
		$shape ||= "ellipse";

		my $b = backbone_color($n);

		# print the node
		print "\t\"$node\" [label=\"$node\\n$n - $t$listing\",shape=$shape,fillcolor=\"$b\",style=filled];\n";
	  }
}

#
# Print all nodes.
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
# Decide how long an edge should be, based on the unique tsize.
# Edges pointing to nodes with small unique tsizes can be long, while
# edges pointing to nodes with large unique tsizes will be short.
# this is useful for the radial graph layout.  it helps the "heavy"
# nodes with large subtrees to cluster near the center of the spider web.
#
sub edge_length
{
	my ($weight) = @_;
	if     ($weight <  10) { 5.0 }
	elsif  ($weight <  30) { 3.0 }
	elsif  ($weight < 100) { 1.0 }
	elsif  ($weight < 150) { 0.5 }
	else                   { 0.1 }
}

#
# Print a single edge.
#
sub print_edge
{
	my ($a, $source, $target, $snipped) = @_;

	# pick a length for this edge, based on unique tsize of the target node.
	my $weight = $a->{'graph'}->unique_tsize($target);
	my $length = edge_length($weight);

	# check whether this edge to the target node should be snipped or not.
	if (should_snip($a, $source, $target))
	  {
		# if so, add target to the cluster for this source
		$snipped->{$source} ||= [];
		push @{$snipped->{$source}}, $target;
	  }
	else
	  {
		# if not, generate the edge
		print "\t\"$source\" -> \"$target\" [len=$length];\n";
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
