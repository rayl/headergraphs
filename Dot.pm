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
# Decide whether an edge to the target node should be snipped in order
# to relax the graph.
#
sub should_snip
{
	my ($a, $target) = @_;
	my $cuts = $a->{'cuts'};

	# we should not snip this edge unless the target has "too many"
	# incoming edges
	return 0 unless exists $cuts->{$target};

	# we want to snip this edge unless it's important (haa a large unique
	# tsize).  in that case, we'd like this "primary hierarchy" to remain
	# contiguous on the graph
	my $weight = $a->{'graph'}->unique_tsize($target);
	my $important = saturation($weight);
	return 1 unless defined $important;

	# this node is part of the "primary hierarchy", but if it has more
	# than 4 incoming edges, we'll snip it anyway.  otherwise, the graph
	# gets too cluttered.
	return 1 unless $cuts->{$target} < 5;

	# do not snip nodes in the primary hierarchy with few incoming edges
	return 0;
}

sub print_node
{
	my ($a, $node) = @_;

	my $g = $a->{'graph'};
	my $t = $g->total_tsize($a->{'file'})->{$node} || "?";
	my $n = $g->unique_tsize($node);
	my $c = saturation($n);

	# if we are printing the root node for this analysis, make it into a yellow house shape
	if ($node eq $a->{'file'})
	  {
		print "\t\"$node\" [label=\"$node\\n($n/$t)\", shape=house, color=\"#0000ff\", fillcolor=\"#ffff00\", style=filled];\n";
	  }


	# if we are printing a node with many incoming edges...
	elsif (should_snip($a, $node))
	  {

		# look up how many incoming edges we have
		my $m = $a->{'cuts'}->{$node};

		# print the node, mentioning how many times it is included
		print "\t\"$node\" [label=\"<$m times>\\n$node\\n($n/$t)\"";


		# if we have determined that this is a popular node with large unique tsize,
		# print it as a red octagon, otherwise just flag it as a yellow diamond
		if (defined $c)
		  {
			my $o = problem_color($c);
			print ", shape=octagon, fillcolor=\"$o\", style=filled";
		  }
		else
		  {
			print ", shape=diamond, fillcolor=\"#ffff80\", style=filled";
		  }
		print "];\n";

		# print the array of ghosts for this node.
		for my $ee (2..$m)
		  {

			# replicate the information from the main node
			print "\t\"$node/$ee\" [label=\"<$m times>\\n$node\\n($n/$t)\", style=dashed";

			# if this is a popular node with large unique tsize, draw it as a dark dashed
			# octagon so it's more visible, without being intrusive.  popular nodes with
			# small unique tsizes just show up as dim dashed circles.
			if (defined $c)
			  {
				print ", shape=octagon, fontcolor=\"#000000\", color=\"#000000\"];\n";
			  }
			else
			  {
				print ", fontcolor=\"#c0c0c0\", color=\"#c0c0c0\"];\n";
			  }
		  }
	  }

	# if we are printing an ordinary node
	else
	  {
		print "\t\"$node\" [label=\"$node\\n($n/$t)\"";
		my $b = backbone_color($c);
		print ", fillcolor=\"$b\", style=filled" if defined $b;
		print "];\n";
	  }
}

#
# Print all nodes.
#
sub print_nodes
{
	my ($a) = @_;

	# walk over each node in the mesh
	for my $node (keys %{$a->{'nodelist'}})
	  {
		print_node($a, $node);
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

	# check whether edges to this target should be snipped or not.
	if (should_snip($a, $target))
	  {
		# increment the number of ghost nodes we have generated for
		# this snipped node
		$ghost->{$target}++;
	  }

	# decide whether to actually snip this particular edge or not.
	if (($ghost->{$target} || 1) < 2)
	  {
		# if target is not a candidate for snipping, or if this is the
		# first time we're printing a snippable target node, then do not
		# snip the edge.  for snippable targets, this will bind the node
		# into the main tree instead of letting it possibly float off to
		# the right edge of the page.
		print "\t\"$source\" -> \"$target\" [len=$length];\n";
	  }
	else
	  {
		# if we've already printed the target node once, snip the edge by
		# generating a unique ghost node for the snipped edge to point at
		print "\t\"$source\" -> \"$target/" . $ghost->{$target} . "\" [len=$length];\n";
	  }
}

#
# Print all edges.
#
sub print_edges
{
	my ($a) = @_;

	# a hash used to uniquely number ghost nodes
	my %ghost;

	# bind a local name to the analysis mesh object
	my $mesh = $a->{'mesh'};

	# walk over each source node
	for my $source (sort keys %$mesh)
	  {
		# walk over each target node for this source
		for my $target (keys %{$mesh->{$source}})
		  {
			# process the edge from source to target
			print_edge($a, $source, $target, \%ghost);
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
	print_ghead($a);
	print_edges($a);
	print_nodes($a);
	print_gfoot($a);
}

1;
