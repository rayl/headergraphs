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
	my ($type, $g, $file) = @_;

	# analysis objects use a hash representation
	my $z = bless {}, ref $type || $type;

	# save the parms for this analysis
	$z->{'graph'} = $g;		# the graph to analyse
	$z->{'file'} = $file;		# the root node for this analysis

	# perform the analysis
	$z->{'mesh'} = {};
	$z->{'nodelist'} = {};
	$z->{'cfiles'} = {};
	$z->collect_parents($file, -1, {});
	$z->remove;
	$z->collapse;

	# return the new object
	$z;
}

1;
