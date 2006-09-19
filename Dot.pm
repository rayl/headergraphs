#
#  Dot.pm - Display an Analysis object using the 'dot' language
#

use 5.6.0;
use strict;
use warnings;

package Dot;

sub node_color
{
	my ($weight) = @_;
	if     ($weight <  25) { undef }
	elsif  ($weight <  50) { "d0" }
	elsif  ($weight < 100) { "80" }
	elsif  ($weight < 150) { "40" }
	else              { "00" }
}

sub octo_color
{
	my ($c) = @_;
	"#ff${c}${c}";
}

sub blue_color
{
	my ($c) = @_;
	"#${c}${c}ff";
}

sub should_snip
{
	my ($a, $target) = @_;

	# figure out how large the subtree rooted at the target is
	my $weight = $a->{'graph'}->unique_tsize($target);

	# check whether we want to color the target node
	my $color = node_color($weight);

	# bind a local name to the list of potential cut points
	my $cuts = $a->{'cuts'};

	# we should snip the edge if the target node qualifies for cutting
	# (in other words, if it has too many incoming edges), FIXME
	exists $cuts->{$target} && ((not defined $color) || ($cuts->{$target} > 4));
}

sub print_node
{
	my ($a, $node) = @_;

	my $g = $a->{'graph'};
	my $t = $g->total_tsize($a->{'file'})->{$node} || "?";
	my $n = $g->unique_tsize($node);
	my $c = node_color($n);
	my $o = octo_color($c) if defined $c;
	my $b = blue_color($c) if defined $c;

	if ($node eq $a->{'file'})
	  {
		print "\t\"$node\" [label=\"$node\\n($n/$t)\", shape=house, color=\"#0000ff\", fillcolor=\"#ffff00\", style=filled];\n";
	  }
	elsif (should_snip($a, $node))
	  {
		my $m = $a->{'cuts'}->{$node};
		if ($g->children($node))
		  {
			print "\t\"$node\" [label=\"<$m times>\\n$node\\n($n/$t)\"";
			if (defined $c)
			  {
				print ", shape=octagon, fillcolor=\"$o\", style=filled";
			  }
			else
			  {
				print ", shape=diamond, fillcolor=\"#ffff80\", style=filled";
			  }
			print "];\n";
		  }
		for my $ee (2..$m)
		  {
			print "\t\"$node/$ee\" [label=\"<$m>\\n$node\\n($n/$t)\", style=dashed";
			if (defined $c)
			  {
				print ", shape=octagon, fontcolor=\"$o\", color=\"$o\"];\n";
			  }
			else
			  {
				print ", fontcolor=\"#c0c0c0\", color=\"#c0c0c0\"];\n";
			  }
		  }
	  }
	else
	  {
		print "\t\"$node\" [label=\"$node\\n($n/$t)\"";
		print ", fillcolor=\"$b\", style=filled" if defined $c;
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
# Decide how long an edge should be, based on how large is the subtree
# rooted at the target of the edge.  Edges pointing to relatively small
# subtrees can be long, while edges pointing to large subtrees will be
# short.  this is useful for the radial graph layout.  it helps the "heavy"
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

	# pick a length for this edge, based on the size of the subtree
	# rooted at the target node.
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
