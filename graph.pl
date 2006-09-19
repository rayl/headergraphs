#!/opt/perl/bin/perl

use 5.6.0;
use strict;
use warnings;
use lib qw(.);

use Data::Dumper;

use Graph;
use Analysis;
use Dot;
use Gather::Linux;
use Report;

# the gatherer which parses source files
my $gatherer = new Gather;

# the raw inclusion information
my $graph;


sub do_it
{
	$graph = $gatherer->run;
}

sub save_it
{
	unless (open D, ">DUMP.bin")
	  {
		print "Failed to open DUMP.bin\n";
		return;
	  }

	print D Data::Dumper->Dump([$graph], [qw(graph)]);

	close D;
}

sub load_it
{
	unless (open D, "<DUMP.bin")
	  {
		print "Failed to open DUMP.bin\n";
		return;
	  }

	my $data = join '', <D>;
 	eval $data;
	close D;
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

sub reporta
{
	Report::report1(Analysis->new($graph, @_));
}

sub reportb
{
	Report::report2(Analysis->new($graph, @_));
}

sub graph1
{
	# my ($file, $clevel, $plevel, $count) = @_;
	Dot::graph2(Analysis->new($graph, @_));
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
	graph1(@_);
	select $stdout;
	$o;
}

sub show
{
	my $dot = graph @_;
	my $ps = $dot;
	$ps =~ s/\.dot$/.ps/;
	print "Running dot...\n";
	system "dot", "-Tps", "-o", $ps, $dot;
	print "Displaying graph...\n";
	system "kghostview", $ps;
	0;
}

sub world
{
	map { show($_, -1, 0, 2) } $graph->nodes;
}

sub x
{
	show($_[0], -1, 0, 2);
}

sub l
{
	load_it
}

sub help
{
	print <<EOF;
  do_it
  save_it
  load_it
  graph file,out,in
  show file,out,in
  report
  trans
EOF
}

#load_it;
#reportb "linux/spinlock.h", -1, 0, 2;
repl;

