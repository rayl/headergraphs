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
# Analyse2.pm - Examine a specific target node in a Graph object
#

use 5.6.0;
use strict;
use warnings;

package Analysis2;

sub collect_parents
{
	my ($z, $file, $n, $visiting) = @_;
	return if $n == 0;
	return if $visiting->{$file};
	$z->{'nodelist'}->{$file} = 1;
	$z->{'mesh'}->{$file} ||= {};
	$visiting->{$file} = 1;
	for my $e ($z->{'graph'}->parents($file))
	  {
		$z->{'mesh'}->{$file}->{$e}++;
		$z->collect_parents($e, $n-1, $visiting);
	  }
	delete $visiting->{$file};
}

#
# Remove all C files as targets of inclusion
#
sub remove
{
	my ($z) = @_;

	# get the list of files
	my @sources = keys %{$z->{'mesh'}};

	# extract the ones named *.c
	my @cfiles = grep {/\.c$/} @sources;

	# and delete each one
	for my $source (@cfiles)
	  {
		delete $z->{'mesh'}->{$source};
		delete $z->{'nodelist'}->{$source};
	  }
}

#
# For each header file, remove all links to c files and remember
# how many there were.
#
sub collapse
{
	my ($z) = @_;

	# for each file which is included by others
	for my $source (keys %{$z->{'mesh'}})
	  {
		# get the list of places which include us
		my @targets = keys %{$z->{'mesh'}->{$source}};

		# extract the ones named *.c
		my @cfiles = grep {/\.c$/} @targets;

		# remember how many there were
		$z->{'cfiles'}->{$source} = scalar(@targets);

		# and delete them
		for my $target (@cfiles)
		  {
			delete $z->{'mesh'}->{$source}->{$target};
		  }
	  }
}

#
# Count number of headers which nest each header file.
#
sub count_nested
{
	my ($z) = @_;
	my $g = $z->{'graph'};

	# for each file which is included by others
	for my $source (keys %{$z->{'mesh'}})
	  {
		# get the list of headers which nest us
		my @targets = keys %{$z->{'mesh'}->{$source}};

		# and remember how many there were
		$z->{'hfiles'}->{$source} = scalar(@targets);
	  }
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
	# cutpoints.  create a hash named 'm' to hold the set of nodes including
	# these cutpoints.
	my %m = map {$_ => []} @{$z->{'graph'}->too_many_p($z->{'file'}, $z->{'many'})};

	# walk over every edge in the mesh incrementing the inclusion counter
	# each time we see a potential cutpoint as the edge target.
	for my $source (keys %{$z->{'mesh'}})
	  {
		for my $target (keys %{$z->{'mesh'}->{$source}})
		  {
			if (exists $m{$target})
			  {
				push @{$m{$target}}, $source;
			  }
		  }
	  }

	# sort each potential cutpoint list by source unique tsize
	my $g = $z->{'graph'};
	for my $target (keys %m)
	  {
		my $x = $m{$target};
		$m{$target} = [ sort {$g->ucsize($b) <=> $g->ucsize($a)} @{$x} ];
	  }

	# save the list of cutpoints and associated inclusion counts
	$z->{'cuts'} = \%m;
}

#
# Create a new analysis object.  Given:
#
#    a graph
#    a root node
#
# analyse the included-by tree for the the specified node and
# store the results.
#
sub new
{
	my ($type, $g, $file, $many) = @_;

	# analysis objects use a hash representation
	my $z = bless {}, ref $type || $type;

	# save the parms for this analysis
	$z->{'graph'} = $g;		# the graph to analyse
	$z->{'file'} = $file;		# the root node for this analysis
	$z->{'many'} = $many || 2;	# how many inclusions is "too many"

	# perform the analysis
	$z->{'mesh'} = {};
	$z->{'nodelist'} = {};
	$z->{'cfiles'} = {};
	$z->{'hfiles'} = {};
	$z->collect_parents($file, -1, {});
	$z->remove;
	$z->collapse;
	$z->count_nested;
	$z->find_potential_cutpoints;

	# return the new object
	$z;
}

1;
