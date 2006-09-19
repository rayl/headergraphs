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


package Graph;

# model include network as digraph using adjacency lists
#     order = count(*.c *.h)
#     size  = count(#include lines)

sub new
{
	my ($type) = @_;

	# graph objects use a hash representation
	my $z = bless {}, ref $type || $type;

	# The source and header files.
	#
	# the graph vertices, one per C and H file.  A hash of file
	# names to Graph::Node objects
	$z->{'vertex'} = {};

	# The '#include's' relationship
	#
	# the edge lists, one per file with '#include' lines. a
	# hash of source node names to a hash of target node
	# names to Graph::Edge objects.
	$z->{'edge'} = {};

	# The '#include'd by' relationship
	#
	# the reverse edge lists, once per '#include' target.  A
	# hash of target node names to a hash of source node
	# names to Graph::Edge objects.
	$z->{'reverse_edge'} = {};

	# the total transitive size, one per node.  a hash of
	# root nodes to integers defining the total number of
	# header files that would be included if that root node
	# were compiled standalone with _NO_ include guards in use.
	$z->{'total_tsize'} = {};

	# the unique transitive size, one per node.  a hash of
	# root nodes to integers defining the unique number of
	# header files that would be included if that root node
	# were compiled standalone with include guards in use.
	$z->{'unique_tsize'} = {};

	# the too_many list, a hash of root nodes to arrays of nodes
	# which are included "many" times in the inclusion graph
	# of that root.
	$z->{'too_many'} = {};

	# the indegree used as the definition of "many".
	# the results of too_many() are cached, but depend on the
	# indegree used as the value of "many".  if this value
	# changes, we notice and flush the cache.
	$z->{'many'} = undef;

	# return the new empty graph object
	$z;
}

# Return a list of all nodes in the graph.
sub nodes
{
	my ($z) = @_;
	sort keys %{$z->{'vertex'}};
}

# Return a given node, creating it if not already present.
sub node
{
	my ($z, $name) = @_;
	$z->{'vertex'}->{$name} ||= Graph::Node->new;
}

# Return the edge from tail to head, creating it if not
# already present.
sub edge
{
	my ($z, $tail, $head) = @_;

	# make sure the nodes exist
	$z->node($tail);
	$z->node($head);

	# do the reverse edge
	$z->{'reverse_edge'}->{$head} ||= {};
	$z->{'reverse_edge'}->{$head}->{$tail} ||= Graph::Edge->new;

	# do the forward edge
	$z->{'edge'}->{$tail} ||= {};
	$z->{'edge'}->{$tail}->{$head} ||= Graph::Edge->new;
}

# Check to see if a given node exists.
sub has_node
{
	my ($z, $node) = @_;
	$z->{'vertex'}->{$node};
}

# Check to see if an edge from tail to head exists.
sub has_edge
{
	my ($z, $tail, $head) = @_;
	if (my $x = $z->{'edge'}->{$tail})
	  {
		$x->{$head};
	  }
}

# Count the number of nodes in the graph.
sub order
{
	my ($z) = @_;
	scalar keys %{$z->{'vertex'}};
}

# Count the number of edges in the graph.
sub size
{
	my ($z) = @_;

	# get a reference to the forward edge table
	my $e = $z->{'edge'};

	# accumulator for the edge count
	my $c;

	# for each edge source in the forward edge table, add
	# the number of edge targets originating at that source
	# to the accumulator
	map {$c += scalar keys %{$e->{$_}}} keys %{$e};

	# return the accumulator
	$c;
}

# Count the number of edges leaving a node. In other words, the
# number of #include lines in that file.
sub degree_out
{
	my ($z, $node) = @_;
	scalar $z->children;
}

# Count the number of edges entering a node. In other words, the
# number of #include lines which reference that file.
sub degree_in
{
	my ($z, $node) = @_;
	scalar $z->parents;
}

# Count the number of edges entering and leaving a node.
sub degree
{
	my ($z, $node) = @_;
	$z->degree_out($node) + $z->degree_in($node);
}

# Return a list of the children of a node. In other words, the
# files included from the given node.
sub children
{
	my ($z, $node) = @_;
	keys %{$z->{'edge'}->{$node} || {}};
}

# Return a list of the parents of a node. In other words, the
# files which include the given node.
sub parents
{
	my ($z, $node) = @_;
	keys %{$z->{'reverse_edge'}->{$node} || {}};
}

# Return a list of nodes which have edges entering or leaving the
# given node.
sub adjacent
{
	my ($z, $node) = @_;
	$z->parents($node), $z->children($node);
}


# An unused breadth-first search routine.
sub bfs
{
	my ($z, $node) = @_;
	my %order;
	my @queue;
	my $count = 0;

	$order{$node} = $count++;
	push @queue, $node;

	while ($node = shift @queue)
	  {
		print "$node\n";
		for $node ($z->children($node))
		  {
			unless (defined $order{$node})
			  {
				$order{$node} = $count++;
				push @queue, $node;
			  }
		  }
	  }

	($count, \%order);
}

# An unused depth-first search helper routine
sub _dfs
{
	my ($z, $node, $pre, $post, $count) = @_;

	print "$node\n";

	$count->[0]++;
	$pre->{$node} = $count->[1]++;
	for $node ($z->children($node))
	  {
		unless (defined $pre->{$node})
		  {
			$z->_dfs($node, $pre, $post, $count);
		  }
	  }
	$post->{$node} = $count->[2]++;
}

# An unused depth-first search routine
sub dfs
{
	my ($z, $node) = @_;
	my %pre;
	my %post;
	my @count = (0, 0, 0);

	$z->_dfs($node, \%pre, \%post, \@count);

	($count[0], \%pre, \%post);
}

# Calculate the unique transitive size for a given root node.
sub _unique_tsize
{
	# node is the current node during the traversal. map
	# holds the _additional_ unique nodes found from each node
	# when they were current during the traversal.
	my ($z, $node, $map) = @_;

	# if we've already visited this node during this particular
	# traversal, then there are no additional unique nodes
	# to be found from here. return zero.
	return 0 if defined $map->{$node};

	# an accumulator for the additional unique tsize of the current
	# node. the current node has not been visited before, so init
	# the accumulator to one.
	my $t = 1;

	# we have now counted the current node, so define it in the
	# map so that the above check will trigger if we come across
	# this node again
	$map->{$node} = 0;

	# add up the additional unique tsizes of all our children
	map {$t += $z->_unique_tsize($_, $map)} $z->children($node);

	# save this total as our additional contribution to the overall
	# tsize of the root node which started the current traversal. if
	# we are the root node which triggered this traversal, then this
	# will be the unique tsize of the inclusion tree rooted at that
	# node.
	$map->{$node} = $t;
}

# Look up (or calculate and cache) the unique tsize for a given root node.
sub unique_tsize
{
	my ($z, $node) = @_;
	$z->{'unique_tsize'}->{$node} ||= $z->_unique_tsize($node, {});
}

# Calculate the total transitive size for all nodes in the inclusion tree
# rooted at a given root node.
sub _total_tsize
{
	# node is the current node during the traversal. total
	# holds the total tsize for each node in the inclusion tree
	# rooted at the original root node.  visiting contains an entry
	# for each active node during the depth-first search.
	my ($z, $node, $total, $visiting) = @_;

	# detect and prevent infinite recursion from circular inclusions.
	return if $visiting->{$node};

	# mark this node as part of the currently active inclusion path
	$visiting->{$node} = 1;

	# every time we visit a node, all nodes in the inclusion path back
	# up the root increase their total tsize by one.
	map {$total->{$_}++} keys %$visiting;

	# process each of our children in turn
	map { $z->_total_tsize($_, $total, $visiting) } $z->children($node);

	# remove this node from the active inclusion path
	delete $visiting->{$node};

	# return the total tsize map constructed so far
	$total;
}

# Look up (or calculate and cache) the total tsize for a given root node.
sub total_tsize
{
	my ($z, $node) = @_;
	$z->{'total_tsize'}->{$node} ||= $z->_total_tsize($node, {}, {});
}

# Calculate the too_many list for a given root node.
sub _too_many
{
	# count tracks how often a file is included.  many is the indegree
	# used as the threshold for "too many" inclusions
	my ($z, $node, $count, $many) = @_;

	# increase the number of times this node has been included
	$count->{$node}++;

	# process each of our children, unless we have already processed the
	# current node, in which case we have already done them.
	map {$z->_too_many($_, $count, $many)} $z->children($node) unless $count->{$node} > 1;

	# return a list of all nodes whose inclusion count exceeds the
	# threshold value
	[ grep {$count->{$_} > $many} keys %$count ];
}

# Look up (or calculate and cache) the too_many list for a given root node.
sub too_many
{
	# many is the indegree used as the threshold for "many" inclusions
	my ($z, $node, $many) = @_;

	# flush the too_many cache if the definition of "many" changes
	unless (defined($z->{'many'}) && ($z->{'many'} == $many))
	  {
		$z->{'too_many'} = {};
		$z->{'many'} = $many;
	  }

	$z->{'too_many'}->{$node} ||= $z->_too_many($node, {}, $many);
}

package Graph::Node;

sub new
{
	my ($type) = @_;
	my $z = bless {}, ref $type || $type;
	$z;
}

package Graph::Edge;

sub new
{
	my ($type) = @_;
	my $z = bless {}, ref $type || $type;
	$z;
}

1;
