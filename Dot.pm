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
# Nodes are colored red or blue if they have sufficiently
# large unique tsize.  The saturation of the color rises with
# increasing unique tsize.
#
sub saturation
{
	my ($weight) = @_;
	if     ($weight <  25) { undef }
	elsif  ($weight <  50) { "d0" }
	elsif  ($weight < 100) { "80" }
	elsif  ($weight < 150) { "40" }
	else              { "00" }
}

#
# Problem nodes (large unique tsize and included many times) have
# a reddish color.
#
sub problem_color
{
	my ($c) = @_;
	"#ff${c}${c}" if defined $c;
}

#
# Backbone nodes (in the "primary inclusion hierarchy") have
# a bluish color.
#
sub backbone_color
{
	my ($c) = @_;
	"#${c}${c}ff" if defined $c;
}

#
# Decide whether an edge to the target node should be snipped in
# order to relax the graph.  if target is not a candidate for snipping, or if this is the
# first time we're printing a snippable target node, then do not
# snip the edge.  for snippable targets, this will bind the node
# into the main tree instead of letting it possibly float off to
# the right edge of the page.
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
	my $important = saturation($weight);
	return 1 unless defined $important;

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
	my ($a, $node, $ghost) = @_;

	my $g = $a->{'graph'};
	my $t = $g->total_tsize($a->{'file'})->{$node} || "?";
	my $n = $g->unique_tsize($node);
	my $c = saturation($n);
	my $listing = "";
	my $shape;

	# if we are printing a node with trimmed outgoing edges
	if (exists $ghost->{$node})
	  {
		# these guys get printed as boxes
		$shape = "box";

		# generate the list of snipped headers
		$listing = "\\n~\\n";
		for my $target (@{$ghost->{$node}})
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

		# if we have determined that this is a popular node with large unique tsize,
		# color it red.  popular nodeswith small tsize are yellow
		my $o = (defined $c) ? problem_color($c) : "#ffffb0";

		# print the node, mentioning how many times it is included
		print "\t\"$node\" [label=\"$node\\n$n - $t - $x$listing\",shape=$shape,fillcolor=\"$o\",style=filled];\n";
	  }

	# if we are printing an ordinary node
	else
	  {
		$shape ||= "ellipse";

		my $b = (defined $c) ? backbone_color($c) : "#f0fff0";

		# print the node
		print "\t\"$node\" [label=\"$node\\n$n - $t$listing\",shape=$shape,fillcolor=\"$b\",style=filled];\n";
	  }
}

#
# Print all nodes.
#
sub print_nodes
{
	my ($a, $ghost) = @_;

	# walk over each node in the mesh
	for my $node (keys %{$a->{'nodelist'}})
	  {
		print_node($a, $node, $ghost);
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
	my ($a, $source, $target, $ghost) = @_;

	# pick a length for this edge, based on unique tsize of the target node.
	my $weight = $a->{'graph'}->unique_tsize($target);
	my $length = edge_length($weight);

	# check whether this edge to the target node should be snipped or not.
	if (should_snip($a, $source, $target))
	  {
		# add target to the cluster for this source
		$ghost->{$source} ||= [];
		push @{$ghost->{$source}}, $target;
	  }
	else
	  {
		# if not, refer directly to the actual node.
		print "\t\"$source\" -> \"$target\" [len=$length];\n";
	  }
}

#
# Print all edges.
#
sub print_edges
{
	my ($a, $ghost) = @_;

	# bind a local name to the analysis mesh object
	my $mesh = $a->{'mesh'};

	# walk over each source node
	for my $source (sort keys %$mesh)
	  {
		# walk over each target node for this source
		for my $target (keys %{$mesh->{$source}})
		  {
			# process the edge from source to target
			print_edge($a, $source, $target, $ghost);
		  }
	  }
}

#
# Print the graph header.
#
# Open a directed graph object and set up the graph
# options.
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
# Close off the digraph object.
#
sub print_gfoot
{
	my ($a) = @_;
	print "}\n";
}

#
# Generate a dot graph in four sections:  A header, followed
# by all edges, then all nodes, and finally a footer.
#
# The input is an analysis object, which has extracted some
# useful bits of information about the topology of an
# underlying graph object.
#
sub graph2
{
	my ($a) = @_;
	my %ghost;
	print_ghead($a);
	print_edges($a, \%ghost);
	print_nodes($a, \%ghost);
	print_gfoot($a);
}

1;
