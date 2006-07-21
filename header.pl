#!/usr/bin/perl

use 5.6.0;
use strict;
use warnings;

# the location of the linux kernel tree
my $tree = "/home/rayl/proj/linux";


# the specific asm-* directories of interest.
# the heuristic used by we_want_dir() is imperfect, but
# should be adequate for i386, arm, mips, and cris, at least...
my ($arch, $mach) = 
	#("arm",   "ep93xx");
	#("arm",   "versatile");
	#("i386",  "generic");
	("x86_64",  "");





# Who do we include? parent => [ child ]
my %includes;

# Who includes us?  child => { parent => count }
my %included;

# Who has double includes?  [ (parent, child, count) ]
my @doubles;

# how many files in our transitive inclusion tree? parent => count
my %count;




#
# Decide whether we want to process a directory.
#
sub we_want_dir
{
	my ($x) = @_;

	return 0 if       $x =~ m,^config(/.*)?$,;
	return 1 if       $x =~ m,^asm-generic$,;
	return 1 unless   $x =~ m,^asm-,;
	return 0 unless   $x =~ m,^asm-$arch(/.*)?$,;
	return 1 unless   $x =~ m,^asm-$arch/(arch|mach)-,;
	return 0 unless   $x =~ m,^asm-$arch/(arch|mach)-$mach(/.*)?$,;
	return 1;
}

#
# Find all interesting directories in the include tree
#
sub interesting_dirs
{
	my @d = `find . -type d`;
	map {s/^..//} @d;
	chomp @d;
	sort grep {we_want_dir $_} @d;
}

#
# Routine to decide whether we want to process a file
#
sub we_want_file
{
	my ($x) = @_;
	return 0 if $x =~ m,^asm-.*/asm-offsets.h$,;
	return 0 if $x =~ m,^linux/autoconf.h$,;
	return 0 if $x =~ m,^linux/compile.h$,;
	return 0 if $x =~ m,^linux/version.h$,;
	return 1;
}

#
# Find all interesting files in a directory
#
sub interesting_files
{
	my ($d) = @_;
	sort grep {we_want_file $_} <$d/*.h>;
}


#
# A routine to extract include lines from a header file
#
sub gather
{
	my ($file) = @_;

	# print "= $file\n";

	open F, "<$file" || die "Can't read $file!";
	my @incs = grep {s,^\s*#\s*include\s*(["<][^>"]*[">]).*,$1,} <F>;
	chomp @incs;
	close F;

	my $dir = $file;
	$dir =~ s,(.*)/.*,$1,;
	map {s,","$dir/,} @incs;

	map {s/^.//} @incs;
	map {s/.$//} @incs;

	$includes{$file} = \@incs;
}

#
# Construct part of %included for the given file
#
sub find_included
{
	my ($file) = @_;

	for my $x (@{$includes{$file}})
	  {
		$included{$x} ||= {};
		$included{$x}->{$file}++;
	  }
}


#
# Find the size of the inclusion tree rooted at a file
#
sub transitive_1
{
	my ($f, $e) = @_;
	$e->{$f} ||= {};
	for my $x (@{$includes{$f}})
	  {
		unless ($e->{$f}->{$x})
		  {
			$e->{$f}->{$x} = 1;
			transitive_1($x, $e);
		  }
	  }
}

sub transitive
{
	my ($file) = @_;
	my %e1;
	transitive_1($file, \%e1);
	my %e2 = map {$_=>1} keys %e1;
	for my $k1 (keys %e1)
	  {
		map {$e2{$_} => 1} keys %{$e1{$k1}};
	  }
	delete $e2{$file};
	$count{$file} = scalar(keys %e2);
}


sub do_it
{
	chdir "$tree/include" || die "Bad tree: $tree";
	map {gather $_} map {interesting_files $_} interesting_dirs;
	map {find_included $_} keys %includes;
	map {transitive $_} keys %includes;
}


do_it;



sub header
{
	print "\n\n==========================\n  $_[0]\n==========================\n";
}

#----------------------------------------------------------
sub report_double
{
	header "Double Inclusion";
	for my $x (keys %included)
	  {
		for my $y (keys %{$included{$x}})
		  {
			my $n = $included{$x}->{$y};
			next unless $n > 1;
			print "!!   DOUBLE-INC: $y includes $x $n times\n";
		  }
	  }
}


#----------------------------------------------------------
sub report_nonexistent
{
	header "Non-existent Files";
	for my $x (keys %includes)
	  {
		for my $f (@{$includes{$x}})
		  {
			next if -f $f;
			next if $f eq "stdarg.h";
			next if $f =~ m,^asm/,;
			print "!! NON-EXISTENT: $x includes $f\n";
		  }
	  }
}

#----------------------------------------------------------
sub report_missingasm
{
	header "Missing ASM Files";
	for my $x (keys %includes)
	  {
		for my $f (@{$includes{$x}})
		  {
			next if -f $f;
			next if $f eq "stdarg.h";
			next unless $f =~ m,^asm/,;
			print "!!  MISSING-ASM: $x includes $f\n";
		  }
	  }
}

#----------------------------------------------------------
sub report_includes
{
	header "Includes";
	for my $x (sort keys %includes)
	  {
		print "$x:\n";
		print "\t$_\n" for @{$includes{$x}};
	  }
}

#----------------------------------------------------------
sub report_included
{
	header "Included by";
	for my $x (sort keys %included)
	  {
		print "$x:\n";
		print "\t$_\n" for @{$included{$x}};
	  }
}

#----------------------------------------------------------
sub report_layering
{
	header "Possible layering violations";
	my @d_asm = qw(acpi config keys math-emu media mtd net pcmcia rdma rxrpc scsi sound video);
	my $x = join '|', @d_asm;
	for my $p (sort grep {m/^asm/} keys %includes)
	  {
		for my $c (@{$includes{$p}})
		  {
			next unless $c =~ m/^($x)\//;
			print "\t$p includes $c\n";
		  }
	  }
}

#----------------------------------------------------------

sub graph_file_out
{
	my ($file, $n, $edges) = @_;
	return if $n == 0;
	$edges->{$file} ||= {};
	for my $e (@{$includes{$file}})
	  {
		next if $edges->{$file}->{$e};
		$edges->{$file}->{$e} = 1;
		graph_file_out($e, $n-1, $edges);
	  }
}

sub graph_file_in
{
	my ($file, $n, $edges) = @_;
	return if $n == 0;
	for my $e (keys %{$included{$file}})
	  {
		$edges->{$e} ||= {};
		next if $edges->{$e}->{$file};
		$edges->{$e}->{$file} = 1;
		graph_file_in($e, $n-1, $edges);
	  }
}

sub graph_node
{
	my ($map, $node) = @_;
	return if $map->{$node};
	my $n = $count{$node} || 0;
	print "\t\"$node\" [label=\"$node\\n($n)\"]\n";
	$map->{$node} = 1;
}

sub graph_edge
{
	my ($e, $f) = @_;
	my $w = $count{$f} || 0;
	my $l;

	if     ($w <  10) { $l = 3.0; }
	elsif  ($w <  30) { $l = 2.0; }
	elsif  ($w < 100) { $l = 1.0; }
	elsif  ($w < 150) { $l = 0.5; }
	else              { $l = 0.1; }

	print "\t\"$e\" -> \"$f\" [len=$l];\n";
}

sub graph_file
{
	my ($file, $out, $in) = @_;
	my %e1;
	my %n;
	print "digraph \"$file\" {\n";
	print "\toverlap=false;\n";
	print "\tsplines=true;\n";
	graph_file_out($file, $out, \%e1);
	graph_file_in($file, $in, \%e1);
	for my $e (sort keys %e1)
	  {
		graph_node(\%n, $e);
		for my $f (sort {($count{$a}||0) <=> ($count{$b}||0)} keys %{$e1{$e}})
		  {
			graph_node(\%n, $f);
			graph_edge($e, $f);
		  }
	  }
	print "};\n";
}



sub repl
{
	use Term::ReadLine;

	my $term = new Term::ReadLine; # ’Simple Perl calc’;
	my $prompt = "Enter a command: ";
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

sub report
{
	report_double;
	report_nonexistent;
	report_missingasm;
}

my $cmd = shift @ARGV;

if ($cmd eq "repl") {
	repl;

} elsif ($cmd eq "transitive") {
	print "$count{$_}\t$_\n" for reverse sort {$count{$a} <=> $count{$b}} keys %count;

} elsif ($cmd eq "graph") {
	graph_file @ARGV;

} else {
	repl;
}

