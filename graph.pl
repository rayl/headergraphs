#!/opt/perl/bin/perl

use 5.6.0;
use strict;
use warnings;


package Graph;

# model include network as digraph using adjacency lists
#     order = count(*.c *.h)
#     size  = count(#include lines)

sub new
{
	my ($type) = @_;

	# graph objects use a hash representation
	my $z = bless {}, ref $type || $type;

	# The source and header files.
	#
	# the graph vertices, one per C and H file.  A hash of file
	# names to Graph::Node objects
	$z->{'vertex'} = {};

	# The '#include's' relationship
	#
	# the edge lists, one per file with '#include' lines. a
	# hash of source node names to a hash of target node
	# names to Graph::Edge objects.
	$z->{'edge'} = {};

	# The '#include'd by' relationship
	#
	# the reverse edge lists, once per '#include' target.  A
	# hash of target node names to a hash of source node
	# names to Graph::Edge objects.
	$z->{'reverse_edge'} = {};

	# the total transitive size, one per node.  a hash of
	# root nodes to integers defining the total number of
	# header files that would be included if that root node
	# were compiled standalone with _NO_ include guards in use.
	$z->{'total_tsize'} = {};

	# the unique transitive size, one per node.  a hash of
	# root nodes to integers defining the unique number of
	# header files that would be included if that root node
	# were compiled standalone with include guards in use.
	$z->{'unique_tsize'} = {};

	# the too_many list, a hash of root nodes to arrays of nodes
	# which are included "many" times in the inclusion graph
	# of that root.
	$z->{'too_many'} = {};

	# the indegree used as the definition of "many".
	# the results of too_many() are cached, but depend on the
	# indegree used as the value of "many".  if this value
	# changes, we notice and flush the cache.
	$z->{'many'} = undef;

	# return the new empty graph object
	$z;
}

# Return a list of all nodes in the graph.
sub nodes
{
	my ($z) = @_;
	sort keys %{$z->{'vertex'}};
}

# Return a given node, creating it if not already present.
sub node
{
	my ($z, $name) = @_;
	$z->{'vertex'}->{$name} ||= Graph::Node->new;
}

# Return the edge from tail to head, creating it if not
# already present.
sub edge
{
	my ($z, $tail, $head) = @_;

	# make sure the nodes exist
	$z->node($tail);
	$z->node($head);

	# do the reverse edge
	$z->{'reverse_edge'}->{$head} ||= {};
	$z->{'reverse_edge'}->{$head}->{$tail} ||= Graph::Edge->new;

	# do the forward edge
	$z->{'edge'}->{$tail} ||= {};
	$z->{'edge'}->{$tail}->{$head} ||= Graph::Edge->new;
}

# Check to see if a given node exists.
sub has_node
{
	my ($z, $node) = @_;
	$z->{'vertex'}->{$node};
}

# Check to see if an edge from tail to head exists.
sub has_edge
{
	my ($z, $tail, $head) = @_;
	if (my $x = $z->{'edge'}->{$tail})
	  {
		$x->{$head};
	  }
}

# Count the number of nodes in the graph.
sub order
{
	my ($z) = @_;
	scalar keys %{$z->{'vertex'}};
}

# Count the number of edges in the graph.
sub size
{
	my ($z) = @_;

	# get a reference to the forward edge table
	my $e = $z->{'edge'};

	# accumulator for the edge count
	my $c;

	# for each edge source in the forward edge table, add
	# the number of edge targets originating at that source
	# to the accumulator
	map {$c += scalar keys %{$e->{$_}}} keys %{$e};

	# return the accumulator
	$c;
}

# Count the number of edges leaving a node. In other words, the
# number of #include lines in that file.
sub degree_out
{
	my ($z, $node) = @_;
	scalar $z->children;
}

# Count the number of edges entering a node. In other words, the
# number of #include lines which reference that file.
sub degree_in
{
	my ($z, $node) = @_;
	scalar $z->parents;
}

# Count the number of edges entering and leaving a node.
sub degree
{
	my ($z, $node) = @_;
	$z->degree_out($node) + $z->degree_in($node);
}

# Return a list of the children of a node. In other words, the
# files included from the given node.
sub children
{
	my ($z, $node) = @_;
	keys %{$z->{'edge'}->{$node} || {}};
}

# Return a list of the parents of a node. In other words, the
# files which include the given node.
sub parents
{
	my ($z, $node) = @_;
	keys %{$z->{'reverse_edge'}->{$node} || {}};
}

# Return a list of nodes which have edges entering or leaving the
# given node.
sub adjacent
{
	my ($z, $node) = @_;
	$z->parents($node), $z->children($node);
}


# An unused breadth-first search routine.
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

# An unused depth-first search helper routine
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

# An unused depth-first search routine
sub dfs
{
	my ($z, $node) = @_;
	my %pre;
	my %post;
	my @count = (0, 0, 0);

	$z->_dfs($node, \%pre, \%post, \@count);

	($count[0], \%pre, \%post);
}

# Calculate the unique transitive size for a given root node.
sub _unique_tsize
{
	# node is the current node during the traversal. map
	# holds the _additional_ unique nodes found from each node
	# when they were current during the traversal.
	my ($z, $node, $map) = @_;

	# if we've already visited this node during this particular
	# traversal, then there are no additional unique nodes
	# to be found from here. return zero.
	return 0 if defined $map->{$node};

	# an accumulator for the additional unique tsize of the current
	# node. the current node has not been visited before, so init
	# the accumulator to one.
	my $t = 1;

	# we have now counted the current node, so define it in the
	# map so that the above check will trigger if we come across
	# this node again
	$map->{$node} = 0;

	# add up the additional unique tsizes of all our children
	map {$t += $z->_unique_tsize($_, $map)} $z->children($node);

	# save this total as our additional contribution to the overall
	# tsize of the root node which started the current traversal. if
	# we are the root node which triggered this traversal, then this
	# will be the unique tsize of the inclusion tree rooted at that
	# node.
	$map->{$node} = $t;
}

# Look up (or calculate and cache) the unique tsize for a given root node.
sub unique_tsize
{
	my ($z, $node) = @_;
	$z->{'unique_tsize'}->{$node} ||= $z->_unique_tsize($node, {});
}

# Calculate the total transitive size for all nodes in the inclusion tree
# rooted at a given root node.
sub _total_tsize
{
	# node is the current node during the traversal. total
	# holds the total tsize for each node in the inclusion tree
	# rooted at the original root node.  visiting contains an entry
	# for each active node during the depth-first search.
	my ($z, $node, $total, $visiting) = @_;

	# detect and prevent infinite recursion from circular inclusions.
	return if $visiting->{$node};

	# mark this node as part of the currently active inclusion path
	$visiting->{$node} = 1;

	# every time we visit a node, all nodes in the inclusion path back
	# up the root increase their total tsize by one.
	map {$total->{$_}++} keys %$visiting;

	# process each of our children in turn
	map { $z->_total_tsize($_, $total, $visiting) } $z->children($node);

	# remove this node from the active inclusion path
	delete $visiting->{$node};

	# return the total tsize map constructed so far
	$total;
}

# Look up (or calculate and cache) the total tsize for a given root node.
sub total_tsize
{
	my ($z, $node) = @_;
	$z->{'total_tsize'}->{$node} ||= $z->_total_tsize($node, {}, {});
}

# Calculate the too_many list for a given root node.
sub _too_many
{
	# count tracks how often a file is included.  many is the indegree
	# used as the threshold for "too many" inclusions
	my ($z, $node, $count, $many) = @_;

	# increase the number of times this node has been included
	$count->{$node}++;

	# process each of our children, unless we have already processed the
	# current node, in which case we have already done them.
	map {$z->_too_many($_, $count, $many)} $z->children($node) unless $count->{$node} > 1;

	# return a list of all nodes whose inclusion count exceeds the
	# threshold value
	[ grep {$count->{$_} > $many} keys %$count ];
}

# Look up (or calculate and cache) the too_many list for a given root node.
sub too_many
{
	# many is the indegree used as the threshold for "many" inclusions
	my ($z, $node, $many) = @_;

	# flush the too_many cache if the definition of "many" changes
	unless ($z->{'many'} == $many)
	  {
		$z->{'too_many'} = {};
		$z->{'many'} = $many;
	  }

	$z->{'too_many'}->{$node} ||= $z->_too_many($node, {}, $many);
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

	$g = Graph->new;

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

	my $t = $total->{$node} || "?";
	my $n = $g->unique_tsize($node);
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

sub unique_tsize_len
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
	my $w = $g->unique_tsize($f);
	my $c = node_color($w);
	my $l = unique_tsize_len($w);

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
	my ($file, $many, $mesh) = @_;
	my %m = map {$_ => 0} @{$g->too_many($file, $many)};
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
		for my $f (sort {$g->unique_tsize($b) <=> $g->unique_tsize($a)} keys %{$mesh->{$e}})
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
	# my ($file, $clevel, $plevel, $count) = @_;
	graph2(analyse(@_));
}

sub analyse
{
	my ($file, $clevel, $plevel, $count) = @_;
	my ($mesh, $total) = extract($file, $clevel, $plevel);
	my $cuts = snip($file, $count, $mesh);
	($file, $mesh, $cuts, $total);
}

my $by_edge_hash;

sub by_total
{
	$by_edge_hash->{$a} <=> $by_edge_hash->{$b} ||
	$a cmp $b;
}

sub by_unique
{
	$g->unique_tsize($a) <=> $g->unique_tsize($b) ||
	$a cmp $b;
}

sub report1
{
	my ($file, $mesh, $cuts, $total) = @_;
	$by_edge_hash = $total;
	for my $e (sort by_total keys %$mesh)
	  {
		my $t = $total->{$e} || "?";
		my $n = $g->unique_tsize($e);
		print "\t$t\t$e ($n)\n";
	  }
}

sub report2
{
	my ($file, $mesh, $cuts, $total) = @_;
	$by_edge_hash = $total;
	for my $e (sort by_unique keys %$mesh)
	  {
		my $t = $total->{$e} || "?";
		my $n = $g->unique_tsize($e);
		print "\t$n\t$e ($t)\n";
	  }
}

sub reporta
{
	report1(analyse(@_));
}

sub reportb
{
	report2(analyse(@_));
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

