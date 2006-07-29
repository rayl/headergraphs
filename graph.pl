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
	$z->{'T'} = {};
	$z->{'X'} = {};
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

sub _tsize
{
	my ($z, $node, $map) = @_;
	return 0 if defined $map->{$node};
	my $t = 1;
	$map->{$node} = 0;
	map {$t += $z->_tsize($_, $map)} $z->children($node);
	$map->{$node} = $t;
}

sub tsize
{
	my ($z, $node) = @_;
	$z->{'T'}->{$node} ||= $z->_tsize($node, {});
}

sub _tmany
{
	my ($z, $node, $map, $count) = @_;
	$map->{$node}++;
	map {$z->_tmany($_, $map, $count)} $z->children($node) unless $map->{$node} > 1;
	[ grep {$map->{$_} > $count} keys %$map ];
}

sub tmany
{
	my ($z, $node, $count) = @_;
	$z->{'X'}->{$node} ||= $z->_tmany($node, {}, $count);
}

sub reset
{
	my ($z) = @_;
	$z->{'T'} = {};
	$z->{'X'} = {};
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

# the location of the linux kernel tree
my $tree = "/home/rayl/proj/linux-headers";


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
	my $c = cwd();

	$t0 = new Benchmark;

	print "process hdrs\n";
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

	chdir $c;
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

sub header
{
	print "\n\n==========================\n  $_[0]\n==========================\n";
}

sub report_includes
{
	header "Includes";
	for my $x ($g->nodes)
	  {
		print "$x:\n";
		print "\t$_\n" for $g->children($x);
	  }
}

sub report_included
{
	header "Included by";
	for my $x ($g->nodes)
	  {
		print "$x:\n";
		print "\t$_\n" for $g->parents($x);
	  }
}

sub collect_children
{
	my ($file, $n, $edges, $total, $visiting) = @_;
	return if $n == 0;
	return if $visiting->{$file};
	$edges->{$file} ||= {};
	$visiting->{$file} = 1;
	map {$total->{$_}++} keys %$visiting;
	for my $e ($g->children($file))
	  {
		$edges->{$file}->{$e}++;
		collect_children($e, $n-1, $edges, $total, $visiting);
	  }
	delete $visiting->{$file};
}

sub collect_parents
{
	my ($file, $n, $edges, $visiting) = @_;
	return if $n == 0;
	return if $visiting->{$file};
	$visiting->{$file} = 1;
	for my $e ($g->parents($file))
	  {
		$edges->{$e} ||= {};
		next if $edges->{$e}->{$file};
		$edges->{$e}->{$file} = 1;
		collect_parents($e, $n-1, $edges, $visiting);
	  }
	delete $visiting->{$file};
}

sub extract
{
	my ($file, $clevel, $plevel) = @_;
	my $x = {};
	my $t = {};
	collect_children($file, $clevel, $x, $t, {});
	collect_parents($file, $plevel, $x, {});
	($x, $t);
}

sub node_color
{
	my ($w) = @_;
	if     ($w <  25) { undef }
	elsif  ($w <  50) { "d0" }
	elsif  ($w < 100) { "80" }
	elsif  ($w < 150) { "40" }
	else              { "00" }
}

sub octo_color
{
	my ($c) = @_;
	"#ff${c}${c}";
}

sub blue_color
{
	my ($c) = @_;
	"#${c}${c}ff";
}

sub snipped
{
	my ($f, $cuts, $c) = @_;
	exists $cuts->{$f} && ((not defined $c) || ($cuts->{$f} > 4));
}

sub graph_node
{
	my ($map, $root, $node, $cuts, $total) = @_;

	return if $map->{$node};
	$map->{$node} = 1;

	my $t = $total->{$node};
	my $n = $g->tsize($node);
	my $c = node_color($n);
	my $o = octo_color($c) if defined $c;
	my $b = blue_color($c) if defined $c;

	if ($root eq $node)
	  {
		print "\t\"$node\" [label=\"$node\\n($n/$t)\", shape=house, color=\"#0000ff\", fillcolor=\"#ffff00\", style=filled];\n";
	  }
	elsif (snipped($node, $cuts, $c))
	  {
		my $m = $cuts->{$node};
		if ($g->children($node))
		  {
			print "\t\"$node\" [label=\"<$m times>\\n$node\\n($n/$t)\"";
			if (defined $c)
			  {
				print ", shape=octagon, fillcolor=\"$o\", style=filled";
			  }
			else
			  {
				print ", shape=diamond, fillcolor=\"#ffff80\", style=filled";
			  }
			print "];\n";
		  }
		for my $ee (1..$m)
		  {
			print "\t\"$node/$ee\" [label=\"<$m>\\n$node\\n($n/$t)\", style=dashed";
			if (defined $c)
			  {
				print ", shape=octagon, fontcolor=\"$o\", color=\"$o\"];\n";
			  }
			else
			  {
				print ", fontcolor=\"#c0c0c0\", color=\"#c0c0c0\"];\n";
			  }
		  }
	  }
	else
	  {
		print "\t\"$node\" [label=\"$node\\n($n/$t)\"";
		print ", fillcolor=\"$b\", style=filled" if defined $c;
		print "];\n";
	  }
}

sub tsize_len
{
	my ($w) = @_;
	if     ($w <  10) { 5.0 }
	elsif  ($w <  30) { 3.0 }
	elsif  ($w < 100) { 1.0 }
	elsif  ($w < 150) { 0.5 }
	else              { 0.1 }
}

sub graph_edge
{
	my ($e, $f, $cuts, $m2) = @_;
	my $w = $g->tsize($f);
	my $c = node_color($w);
	my $l = tsize_len($w);

	if (snipped($f, $cuts, $c))
	  {
		$m2->{$f}++;
		print "\t\"$e\" -> \"$f/" . $m2->{$f} . "\" [len=$l];\n";
	  }
	else
	  {
		print "\t\"$e\" -> \"$f\" [len=$l];\n";
	  }
}

sub snip
{
	my ($file, $count, $mesh) = @_;
	my %m = map {$_ => 0} @{$g->tmany($file, $count)};
	map {$m{$_}++ if exists $m{$_}} map {keys %{$mesh->{$_}}} sort keys %$mesh;
	\%m;
}

sub print_ghead
{
	my ($file, $mesh, $cuts, $total) = @_;
	print "digraph \"$file\" {\n";
	print "\toverlap=false;\n";
	print "\tsplines=true;\n";
	print "\troot=\"$file\";\n";
}

sub print_edges
{
	my ($file, $mesh, $cuts, $total) = @_;
	my %m2;
	for my $e (sort keys %$mesh)
	  {
		for my $f (keys %{$mesh->{$e}})
		  {
			graph_edge($e, $f, $cuts, \%m2);
		  }
	  }
}

sub print_nodes
{
	my ($file, $mesh, $cuts, $total) = @_;
	my %n;
	for my $e (sort keys %$mesh)
	  {
		graph_node(\%n, $file, $e, $cuts, $total);
		for my $f (sort {$g->tsize($b) <=> $g->tsize($a)} keys %{$mesh->{$e}})
		  {
			graph_node(\%n, $file, $f, $cuts, $total);
		  }
	  }
}

sub print_gfoot
{
	my ($file, $mesh, $cuts, $total) = @_;
	print "}\n";
}

sub graph2
{
	print_ghead(@_);
	print_edges(@_);
	print_nodes(@_);
	print_gfoot(@_);
}

sub graph1
{
	my ($file, $clevel, $plevel, $count) = @_;
	my ($mesh, $total) = extract($file, $clevel, $plevel);
	my $cuts = snip($file, $count, $mesh);
	graph2($file, $mesh, $cuts, $total);
}

sub graph
{
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
	$g->reset;
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

repl;

