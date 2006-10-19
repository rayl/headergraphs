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
use Analysis2;
use Dot2;
use Report;

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

# the output format flag and extension
my $flag = "png";
my $ext = "png";
my @viewer = ("gwenview", "-f");


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

sub banner
{
	my $n = $_[0];
	my $l = length($n);
	print ("=" x 80 . "\n");
	print (" " x (40-($l/2)) . "$_[0]\n");
	print ("=" x 80 . "\n");
}

sub report
{
	# my ($file, $clevel, $plevel, $count) = @_;
	my $a = Analysis->new($graph, (@_));
	banner($_[0]);
	print "\n\nNodes sorted by unique tsize\n";
	Report::unique($a);
	print "\nNodes sorted by total tsize\n";
	Report::total($a);
	print "\n\nNodes sorted by name\n";
	Report::name($a);
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
	close O;
	$o;
}

sub graph2
{
	# my ($file) = @_;
	my ($o) = @_;
	$o =~ s/[.\/]/_/g;
	$o =~ s/$/.dot/;
	$o =~ s/^/tmp\//;
	open O, ">$o" || return;
	my $stdout = select O;
	Dot2::graph2(Analysis2->new($graph, (@_)));
	select $stdout;
	close O;
	$o;
}

sub fmt
{
	my ($type) = @_;

	if ($type eq "png")
	  {
		($flag, $ext, @viewer) = ("png", "png", "gwenview", "-f");
	  }
	elsif ($type eq "ps")
	  {
		($flag, $ext, @viewer) = ("ps", "ps", "kghostview");
	  }
	elsif ($type eq "jpg")
	  {
		($flag, $ext, @viewer) = ("jpg", "jpg", "gwenview", "-f");
	  }
	else
	  {
		print "Unknown type: $type\n";
	  }
}

sub show
{
	# my ($file, $clevel, $plevel, $count) = @_;
	my $dot = graph @_;
	my $out = $dot;
	$out =~ s/\.dot$/.$ext/;
	print "Running dot...\n";
	system "dot", "-T$flag", "-o", $out, $dot;
	print "Displaying graph...\n";
	system @viewer, $out;
	0;
}

sub show2
{
	# my ($file) = @_;
	my $dot = graph2 @_;
	my $out = $dot;
	$out =~ s/\.dot$/.$ext/;
	print "Running dot...\n";
	system "dot", "-T$flag", "-o", $out, $dot;
	print "Displaying graph...\n";
	system @viewer, $out;
	0;
}

sub x
{
	show($_[0], -1, 0, 2);
}

sub z
{
	report($_[0], -1, 0, 2);
}

sub world
{
	my @nodes = grep {$graph->ucsize($_) > 10} grep {$_ =~ m/\.h$/} sort $graph->nodes;
	my @nodes2 = sort {$graph->ucsize($a) <=> $graph->ucsize($b)} @nodes;

	print "Doing " . scalar(@nodes2) . " nodes, max tsize " . $graph->ucsize($nodes2[-1]) . "\n";
	my $i = "00000";
	for my $file (@nodes2)
	  {
		my $u = $graph->ucsize($file);
		my $t = $graph->tcsize($file)->{$file};
		print "$u - $t  $i-$file\n";
		my $dot = graph($file, -1, 0, 2);
		$dot =~ s,tmp/,,;
		`mv tmp/$dot tmp/$i-$dot`;
		$i++;
	  }
}

sub help
{
	print <<EOF;
  do_it
  save_it
  load_it
  graph file,out,in,cut
  graph2 file
  fmt ["png"|"ps"|"jpg"]
  show file,out,in,cut
  show2 file
  x file
  report file,out,in,cut
  z file
  world
EOF
}

load_it;
show2 "linux/skbuff.h";
repl;

