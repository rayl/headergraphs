#!/opt/perl/bin/perl

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
use lib qw(.);

use Data::Dumper;

use Gather::Linux;
use Gather::Git;
use Graph;
use Analysis;
use Dot;

##############################################################################
#
# Create the gatherer which parses source files
#
my $gatherer = new Gather::Linux("/opt/BR/src/linux", "x86_64");
#my $gatherer = new Gather::Git("/home/rayl/proj/git");
#
##############################################################################

# the raw inclusion information
my $graph;


sub do_it
{
	$graph = $gatherer->run;
}

sub save_it
{
	if (open D, ">DUMP.bin")
	  {
		print D Data::Dumper->Dump([$graph], [qw(graph)]);
		close D;
	  }
	else
	  {
		print "Failed to open DUMP.bin\n";
	  }
}

sub load_it
{
	if (open D, "<DUMP.bin")
	  {
		my $data = join '', <D>;
 		eval $data;
		close D;
	  }
	else
	  {
		print "Failed to open DUMP.bin\n";
	  }
}

sub repl
{
	use Term::ReadLine;

	my $term = new Term::ReadLine; # ’Simple Perl calc’;
	my $prompt = "Enter a command (type 'help' for list): ";
	my $OUT = $term->OUT || \*STDOUT;

	while (defined ($_ = $term->readline($prompt)))
	  {
		my $res = eval($_);
		warn $@ if $@;
		print $OUT $res, "\n" unless $@;
		$term->addhistory($_) if /\S/;
	  }

	print "\n\n";
}

sub graph
{
	# my ($file, $clevel, $plevel, $count) = @_;
	my ($o) = @_;
	$o =~ s/[.\/]/_/g;
	$o =~ s/$/.dot/;
	$o =~ s/^/tmp\//;
	open O, ">$o" || return;
	my $stdout = select O;
	Dot::graph2(Analysis->new($graph, (@_)));
	select $stdout;
	$o;
}

sub show
{
	# my ($file, $clevel, $plevel, $count) = @_;
	my $dot = graph @_;
	my $png = $dot;
	$png =~ s/\.dot$/.png/;
	print "Running dot...\n";
	system "dot", "-Tpng", "-o", $png, $dot;
	print "Displaying graph...\n";
	system "gwenview", $png;
	0;
}

sub x
{
	show($_[0], -1, 0, 2);
}

sub help
{
	print <<EOF;
  do_it
  save_it
  load_it
  graph file,out,in,cut
  show file,out,in,cut
  x file
EOF
}

#load_it;
#x "linux/sched.h";
repl;

