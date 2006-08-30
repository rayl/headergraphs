#!/opt/perl/bin/perl

use 5.6.0;
use strict;
use warnings;
use lib qw(.);

use Data::Dumper;

use Graph;
use Analysis;
use Dot;
use Gather;
use Report;

# the raw inclusion information
my $g;


sub do_it
{
	$g = Gather::do_it();
}

sub save_it
{
	unless (open D, ">DUMP.bin")
	  {
		print "Failed to open DUMP.bin\n";
		return;
	  }

	print D Data::Dumper->Dump([$g], [qw(g)]);

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
	Report::report1($g, Analysis::analyse($g, @_));
}

sub reportb
{
	Report::report2($g, Analysis::analyse($g, @_));
}

sub graph1
{
	# my ($file, $clevel, $plevel, $count) = @_;
	Dot::graph2($g, Analysis::analyse($g, @_));
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
  load
  dump
  graph file,out,in
  show file,out,in
  report
  trans
EOF
}

#load_it;
#reportb "linux/spinlock.h", -1, 0, 2;
repl;

