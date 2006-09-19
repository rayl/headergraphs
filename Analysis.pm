#
# Analyse.pm - Examine a specific root node in a Graph object
#
# Any given Analysis object is only valid for one root node
# of one Graph object, but any Graph object may have many
# Analysis objects associated with it.
#

use 5.6.0;
use strict;
use warnings;

package Analysis;

sub collect_children
{
	my ($z, $file, $n, $visiting) = @_;
	return if $n == 0;
	return if $visiting->{$file};
	$z->{'nodelist'}->{$file} = 1;
	$z->{'mesh'}->{$file} ||= {};
	$visiting->{$file} = 1;
	for my $e ($z->{'graph'}->children($file))
	  {
		$z->{'mesh'}->{$file}->{$e}++;
		$z->collect_children($e, $n-1, $visiting);
	  }
	delete $visiting->{$file};
}

sub collect_parents
{
	my ($z, $file, $n, $visiting) = @_;
	return if $n == 0;
	return if $visiting->{$file};
	$visiting->{$file} = 1;
	$z->{'nodelist'}->{$file} = 1;
	for my $e ($z->{'graph'}->parents($file))
	  {
		$z->{'mesh'}->{$e} ||= {};
		next if $z->{'mesh'}->{$e}->{$file};
		$z->{'mesh'}->{$e}->{$file} = 1;
		$z->collect_parents($e, $n-1, $visiting);
	  }
	delete $visiting->{$file};
}

#
# Based on the "too many" criteria, identify nodes whose incoming edges could
# be snipped in order to relax the graph and count how many times they are
# included.
#
sub find_potential_cutpoints
{
	my ($z) = @_;

	# ask the graph to scan the inclusion tree rooted at 'file' and return
	# a list of nodes with 'many' or more incoming edges.  these are the potential
	# cutpoints.  create a hash named 'm' to count the actual number of inclusions
	# for each one.
	my %m = map {$_ => 0} @{$z->{'graph'}->too_many($z->{'file'}, $z->{'many'})};

	# walk over every edge in the mesh incrementing the inclusion counter
	# each time we see a potential cutpoint as the edge target.
	map {$m{$_}++ if exists $m{$_}} map {keys %{$z->{'mesh'}->{$_}}} sort keys %{$z->{'mesh'}};

	# save the list of cutpoints and associated inclusion counts
	$z->{'cuts'} = \%m;
}

#
# Create a new analysis object.  Given:
#
#    a graph
#    a root node
#    recursion depths for children and parents
#    a threshold for "too many" inclusions
#
# analyse the inclusion tree rooted at the specified node and
# store the results.
#
sub new
{
	my ($type, $g, $file, $clevel, $plevel, $many) = @_;

	# analysis objects use a hash representation
	my $z = bless {}, ref $type || $type;

	# save the parms for this analysis
	$z->{'graph'} = $g;		# the graph to analyse
	$z->{'file'} = $file;		# the root node for this analysis
	$z->{'clevel'} = $clevel;	# how many levels to follow children
	$z->{'plevel'} = $plevel;	# how many levels to follow parents
	$z->{'many'} = $many;		# how many inclusions is "too many"

	# perform the analysis
	$z->{'mesh'} = {};
	$z->{'nodelist'} = {};
	$z->collect_children($file, $clevel, {});
	$z->collect_parents($file, $plevel, {});
	$z->find_potential_cutpoints;

	# return the new object
	$z;
}

1;
