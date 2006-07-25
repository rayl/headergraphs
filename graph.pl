#!/opt/perl/bin/perl

use 5.6.0;
use strict;
use warnings;


package Graph;

# model include network as digraph using adjacency lists
#     order = count(*.c *.h)
#     size  = count(#include lines)

# keep a forward graph (includes) and a reverse (included)

# other node data
#     inclusion tree size (order of graph rooted at node)

sub new
{
	my ($type) = @_;
	my $z = bless {}, ref $type || $type;
	$z->{'V'} = {};
	$z->{'E'} = {};
	$z->{'R'} = {};
	$z;
}

sub nodes
{
	my ($z) = @_;
	sort keys %{$z->{'V'}};
}

sub node
{
	my ($z, $name) = @_;
	$z->{'V'}->{$name} ||= Graph::Node->new;
}

sub edge
{
	my ($z, $tail, $head) = @_;

	# make sure the nodes exist
	$z->node($tail);
	$z->node($head);

	# do the reverse edge
	$z->{'R'}->{$head} ||= {};
	$z->{'R'}->{$head}->{$tail} ||= Graph::Edge->new;

	# do the forward edge
	$z->{'E'}->{$tail} ||= {};
	$z->{'E'}->{$tail}->{$head} ||= Graph::Edge->new;
}

sub has_node
{
	my ($z, $node) = @_;
	$z->{'V'}->{$node};
}

sub has_edge
{
	my ($z, $tail, $head) = @_;
	if (my $x = $z->{'E'}->{$tail})
	  {
		$x->{$head};
	  }
}

sub order
{
	my ($z) = @_;
	scalar keys %{$z->{'V'}};
}

sub size
{
	my ($z) = @_;
	my $e = $z->{'E'};
	my $c;
	map {$c += scalar keys %{$e->{$_}}} keys %{$e};
	$c;
}

sub degree_out
{
	my ($z, $node) = @_;
	scalar keys %{$z->{'E'}->{$node} || {}};
}

sub degree_in
{
	my ($z, $node) = @_;
	scalar keys %{$z->{'R'}->{$node} || {}};
}

sub degree
{
	my ($z, $node) = @_;
	$z->degree_out($node) + $z->degree_in($node);
}

sub children
{
	my ($z, $node) = @_;
	keys %{$z->{'E'}->{$node} || {}};
}

sub parents
{
	my ($z, $node) = @_;
	keys %{$z->{'R'}->{$node} || {}};
}

sub adjacent
{
	my ($z, $node) = @_;
	$z->parents($node), $z->children($node);
}


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

sub dfs
{
	my ($z, $node) = @_;
	my %pre;
	my %post;
	my @count = (0, 0, 0);

	$z->_dfs($node, \%pre, \%post, \@count);

	($count[0], \%pre, \%post);
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


package main;

use Benchmark;
use Data::Dumper;
use Cwd;

sub show { my $x = shift || "<UNDEF>"; print "$x\n" }


# the location of the linux kernel tree
my $tree = "/home/rayl/proj/linux";


# the specific asm-* directories of interest.
# the heuristic used by we_want_hdr_dir() is imperfect, but
# should be adequate for i386, arm, mips, and cris, at least...
my ($arch, $mach) = 
	#("arm",   "ep93xx");
	#("arm",   "versatile");
	#("i386",  "generic");
	("x86_64",  "");


# the forward (includes) digraph
my $g = Graph->new;



#
# Decide whether we want to process a header directory.
#
sub we_want_hdr_dir
{
	my ($x) = @_;
	return 0 if       $x =~ m,^config(/.*)?$,;
	return 1 if       $x =~ m,^asm-generic$,;
	return 0 if       $x =~ m,^asm-,;
	return 0 if       $x =~ m,^asm/(mach|arch)-,;
	return 1;
}

#
# Find all interesting header directories in the include tree
#
sub interesting_hdr_dirs
{
	my @d = `find . -type d -o -type l`;
	map {s/^..//} @d;
	chomp @d;
	sort grep {we_want_hdr_dir $_} @d;
}

#
# Routine to decide whether we want to process a header file
#
sub we_want_hdr_file
{
	my ($x) = @_;
	return 0 if $x =~ m,^asm.*/asm-offsets.h$,;
	return 0 if $x =~ m,^linux/autoconf.h$,;
	return 0 if $x =~ m,^linux/compile.h$,;
	return 0 if $x =~ m,^linux/compiler.h$,;
	return 0 if $x =~ m,^linux/version.h$,;
	return 1;
}

#
# Find all interesting header files in a directory
#
sub interesting_hdr_files
{
	my ($d) = @_;
	sort grep {we_want_hdr_file $_} <$d/*.h>;
}

#
# Decide whether we want to process a source directory.
#
sub we_want_src_dir
{
	my ($x) = @_;
	return 0 if       $x =~ m,^Documentation/,;
	return 0 if       $x =~ m,^\.git/,;
	return 0 if       $x =~ m,^include/,;
	return 0 if       $x =~ m,^scripts/,;
	return 0 if       $x =~ m,^\.tmp_versions/,;
	return 0 if       $x =~ m,^usr/,;
	return 1 unless   $x =~ m,^arch/,;
	return 0 unless   $x =~ m,^arch/$arch(/.*)?$,;
	return 1;
}

#
# Find all interesting source directories in the include tree
#
sub interesting_src_dirs
{
	my @d = `find . -type d`;
	map {s/^..//} @d;
	chomp @d;
	sort grep {we_want_src_dir $_} @d;
}

#
# Routine to decide whether we want to process a source file
#
sub we_want_src_file
{
	my ($x) = @_;
	return 1;
}

#
# Find all interesting source files in a directory
#
sub interesting_src_files
{
	my ($d) = @_;
	sort grep {we_want_src_file $_} <$d/*.c>;
}

#
# Extract include lines from a file
#
sub gather
{
	my ($file) = @_;

	# bail if we've already parsed this file for some reason
	my $n = $g->node($file);
	return if $n->{'parsed'};

	# remember that we've parsed this file
	$n->{'parsed'} = 1;

	# read the raw #include lines
	open F, "<$file" || die "Can't read $file!";
	my @incs = grep {s,^\s*#\s*include\s*(["<][^>"]*[">]).*,$1,} <F>;
	chomp @incs;
	close F;

	# add current directory to #include "" lines
	my $dir = $file;
	$dir =~ s,(.*)/.*,$1,;
	map {s,","$dir/,} @incs;

	# trim the <> or "" characters
	map {s/^.//} @incs;
	map {s/.$//} @incs;

	# create edges for each inclusion
	for my $h (@incs)
	  {
		$g->edge($file, $h);
	  }
}


sub do_it
{
	my ($t0, $t1);

	$t0 = new Benchmark;

	print "process hdrs\n";
	chdir "$tree/include" || die "Bad tree: $tree";
	map {gather $_} map {interesting_hdr_files $_} interesting_hdr_dirs;
	$t1 = new Benchmark;
	print "Took " . timestr(timediff($t1, $t0)) . " seconds\n";
	$t0 = $t1;

	if (0)
	  {
		print "process src\n";
		chdir "$tree" || die "Bad tree: $tree";
		map {gather $_} map {interesting_src_files $_} interesting_src_dirs;
		$t1 = new Benchmark;
		print "Took " . timestr(timediff($t1, $t0)) . " seconds\n";
		$t0 = $t1;
	  }
}


do_it;

show $g->order;
show $g->size;

show $g->degree("linux/posix_types.h");
show $g->degree_in("linux/posix_types.h");
show $g->degree_out("linux/posix_types.h");

my ($count, $order) = $g->bfs("linux/types.h");
show $count;
for (sort {$order->{$a} <=> $order->{$b}} keys %{$order})
  {
	print "   $_ => $order->{$_}\n";
  }

my ($count, $pre, $post) = $g->dfs("linux/types.h");
show $count;
for (sort {$pre->{$a} <=> $pre->{$b}} keys %{$pre})
  {
	print "   $_ => $pre->{$_}\n";
  }
for (sort {$post->{$a} <=> $post->{$b}} keys %{$post})
  {
	print "   $_ => $post->{$_}\n";
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

repl;

__END__



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
	my ($t0, $t1);
	my ($cwd) = cwd();

	print "process hdrs\n";
	$t0 = new Benchmark;
	chdir "$tree/include" || die "Bad tree: $tree";
	map {gather $_} map {interesting_hdr_files $_} interesting_hdr_dirs;
	$t1 = new Benchmark;
	print "Took " . timestr(timediff($t1, $t0)) . " seconds\n";
	$t0 = $t1;

	print "process src\n";
	chdir "$tree" || die "Bad tree: $tree";
	map {gather $_} map {interesting_src_files $_} interesting_src_dirs;
	$t1 = new Benchmark;
	print "Took " . timestr(timediff($t1, $t0)) . " seconds\n";
	$t0 = $t1;

	print "find included\n";
	map {find_included $_} keys %includes;
	$t1 = new Benchmark;
	print "Took " . timestr(timediff($t1, $t0)) . " seconds\n";
	$t0 = $t1;

	print "transitive\n";
	map {transitive $_} keys %includes;
	$t1 = new Benchmark;
	print "Took " . timestr(timediff($t1, $t0)) . " seconds\n";

	chdir $cwd;
	"";
}


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

sub node_color
{
	my ($w) = @_;
	if     ($w <  10) { undef }
	elsif  ($w <  30) { "#ffd0d0" }
	elsif  ($w < 100) { "#ff8080" }
	elsif  ($w < 150) { "#ff4040" }
	else              { "#ff0000" }
}

sub graph_node
{
	my ($map, $root, $node, $minout) = @_;
	return if $map->{$node};
	my $n = $count{$node} || 0;
	return if $n < $minout;
	print "\t\"$node\" [label=\"$node\\n($n)\"";
	if ($root eq $node)
	  {
		print ", shape=house, color=\"#0000ff\", fillcolor=\"#ffff00\", style=filled";
	  }
	else
	  {
		my $c = node_color($n);
		print ", fillcolor=\"$c\", style=filled" if defined $c;
	  }
	print "]\n";
	$map->{$node} = 1;
}

sub graph_edge
{
	my ($e, $f, $minout) = @_;
	my $w0 = $count{$e} || 0;
	my $w = $count{$f} || 0;
	my $l;

	return if $w0 < $minout;
	return if $w < $minout;

	if     ($w <  10) { $l = 5.0; }
	elsif  ($w <  30) { $l = 3.0; }
	elsif  ($w < 100) { $l = 1.0; }
	elsif  ($w < 150) { $l = 0.5; }
	else              { $l = 0.1; }

	print "\t\"$e\" -> \"$f\" [len=$l];\n";
}

sub graph
{
	my ($file, $out, $in, $minout) = @_;
	my %e1;
	my %n;
	my $o = $file;
	$o =~ s/[.\/]/_/g;
	$o =~ s/$/.dot/;
	$o =~ s/^/tmp\//;
	open O, ">$o" || return;
	my $stdout = select O;
	$minout ||= 0;
	print "digraph \"$file\" {\n";
	print "\toverlap=false;\n";
	print "\tsplines=true;\n";
	print "\troot=\"$file\";\n";
	graph_file_out($file, $out, \%e1);
	graph_file_in($file, $in, \%e1);
	for my $e (sort keys %e1)
	  {
		graph_node(\%n, $file, $e, $minout);
		for my $f (sort {($count{$b}||0) <=> ($count{$a}||0)} keys %{$e1{$e}})
		  {
			graph_node(\%n, $file, $f, $minout);
			graph_edge($e, $f, $minout);
		  }
	  }
	print "}\n";
	select $stdout;
	$o;
}

sub report
{
	report_double;
	report_nonexistent;
	report_missingasm;
}

sub trans_data
{
	reverse sort {$count{$a} <=> $count{$b}} keys %count;
}

sub trans_print
{
	shift @_;
	print "$count{$_}\t$_\n";
}

sub trans
{
	&trans_print for &trans_data;
}

sub save_it
{
	unless (open D, ">DUMP.bin")
	  {
		print "Failed to open DUMP.bin\n";
		return;
	  }

	print D Data::Dumper->Dump([\%includes, \%included, \%count], [qw(a b c)]);

	close D;
}

sub load_it
{
	my ($a, $b, $c);

	unless (open D, "<DUMP.bin")
	  {
		print "Failed to open DUMP.bin\n";
		return;
	  }

	my $data = join '', <D>;
 	eval $data;

	%includes = %$a;
	%included = %$b;
	%count = %$c;

	close D;
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


repl;

