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

	# we know that there are more then one incoming edges, so figure out
	# how many there are
	my $n = scalar @{$cuts->{$target}};

	# this target has lots of incoming edges, but we always want the one
	# with the smallest unique tsize to reamin intact, no matter what.
	# this avoids disconnected subtrees floating over to the right side
	# of the page.
	return 0 if $cuts->{$target}->[$n-1] eq $source;
	#return 0 if $cuts->{$target}->[0] eq $source;

	# this is one of the less important links to the target. we prefer to
	# snip these edges unless the target is a part of the backbone.  in
	# that case, we'd like this "primary hierarchy" to remain contiguous
	# on the graph
	my $weight = $a->{'graph'}->ucsize($target);
	return 1 unless backbone($weight);

	# this node is part of the blue backbone.  if there are less than 3
	# incoming edges, we want to keep things contiguous.
	return 0 if scalar @{$cuts->{$target}} < 3;

	# the node is part of the backbone, but has too many incoming edges
	# to keep everything contiguous while maintaining a clean layout.
	# we know it's not the lightest incoming edge, so check next one and
	# keep it, snipping the rest.
	return 0 if $cuts->{$target}->[$n-2] eq $source;
	#return 0 if $cuts->{$target}->[1] eq $source;
	return 1;
}

sub by_ucsize
{
	my ($g, $node, $snipped) = @_;
	sort {$g->ucsize($b) <=> $g->ucsize($a)} @{$snipped->{$node}};
}

sub print_node
{
	my ($a, $node, $snipped) = @_;

	my $g = $a->{'graph'};
	my $t = $g->tcsize($a->{'file'})->{$node} || "?";
	my $n = $g->ucsize($node);

	my $snips = "";
	my $shape;
	my $count = "$n - $t";
	my $fill;

	if (exists $snipped->{$node})
	  {
		# we are printing a node with trimmed outgoing edges
		$shape = "box";

		# generate the list of snipped headers
		$snips = "\\n\\n";

		for my $target (by_ucsize($g, $node, $snipped))
		  {
			my $nn = $g->ucsize($target);
			my $tt = $g->tcsize($a->{'file'})->{$target} || "?";
			my $xx = scalar @{$a->{'cuts'}->{$target}};
			$snips .= "$target $nn - $tt - $xx\\n";
		  }
	  }

	if (exists $a->{'cuts'}->{$node})
	  {
		# we are printing a node with many incoming edges...
		$shape ||= "ellipse";
		$fill = target_color($n);

		my $x = scalar @{$a->{'cuts'}->{$node}};
		$count .= " - $x";
	  }

	else
	  {
		# we are printing an ordinary node
		$shape ||= "ellipse";
		$fill = backbone_color($n);
	  }

	# generate the node
	print "\t\"$node\" [label=\"${node}\\n${count}${snips}\",shape=${shape},fillcolor=\"${fill}\",style=filled];\n";
}

#
# Print all nodes except root.
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
	my $t = $g->tcsize($a->{'file'})->{$node} || "?";
	my $n = $g->ucsize($node);

	my $snips = "";
	my $count = "$n - $t";
	my $shape = "house";
	my $fill = "#ff8000";

	print "\t\"$node\" [label=\"${node}\\n${count}${snips}\",shape=${shape},fillcolor=\"${fill}\",style=filled];\n";

	for (; $roots != 0; $roots--)
	  {
		print "\t\"$node/$roots\" [label=\"*\",shape=circle,fillcolor=\"#ff8000\",style=filled];\n";
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
	my ($a, $source, $target, $snipped, $roots) = @_;

	# pick a length for this edge, based on unique tsize of the target node.
	my $weight = $a->{'graph'}->ucsize($target);
	my $length = edge_length($weight);

	# check whether this edge to the target node should be snipped or not.
	if ((defined $roots) && ($source eq $a->{'file'}))
	  {
		# increment the number of virtual root nodes to generate
		${$roots}++;

		# generate an edge from the virtual root node
		print "\t\"$source/${$roots}\" -> \"$target\" [len=$length];\n";
	  }
	elsif (should_snip($a, $source, $target))
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

	# only generate virtual roots if we have > 3 child on root node
	my $x;
	if (scalar keys %{$mesh->{$a->{'file'}}} > 3) 
	  {
		my $roots;
		$x = \$roots;
	  }

	# walk over each source node
	for my $source (sort keys %$mesh)
	  {
		# walk over each target node for this source
		for my $target (keys %{$mesh->{$source}})
		  {
			print_edge($a, $source, $target, $snipped, $x);
		  }
	  }

	# return the number of virtual root nodes to generate
	(defined $x) ? $$x : 0;
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
