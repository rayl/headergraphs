
use 5.6.0;
use strict;
use warnings;

package Dot;

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
	my ($g, $map, $root, $node, $cuts, $total) = @_;

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
		for my $ee (2..$m)
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
	my ($g, $e, $f, $cuts, $m2) = @_;
	my $w = $g->unique_tsize($f);
	my $c = node_color($w);
	my $l = unique_tsize_len($w);

	if (snipped($f, $cuts, $c))
	  {
		$m2->{$f}++;
		if ($m2->{$f} == 1)
		  {
			print "\t\"$e\" -> \"$f\" [len=$l];\n";
		  }
		else
		  {
			print "\t\"$e\" -> \"$f/" . $m2->{$f} . "\" [len=$l];\n";
		  }
	  }
	else
	  {
		print "\t\"$e\" -> \"$f\" [len=$l];\n";
	  }
}

sub print_ghead
{
	my ($a) = @_;
	my $file = $a->{'file'};
	print "digraph \"$file\" {\n";
	print "\toverlap=false;\n";
	print "\tsplines=true;\n";
	print "\troot=\"$file\";\n";
}

sub print_edges
{
	my ($a) = @_;
	my ($g, $file, $mesh, $cuts) = ($a->{'graph'}, $a->{'file'}, $a->{'mesh'}, $a->{'cuts'});
	my %m2;
	for my $e (sort keys %$mesh)
	  {
		for my $f (keys %{$mesh->{$e}})
		  {
			graph_edge($g, $e, $f, $cuts, \%m2);
		  }
	  }
}

sub print_nodes
{
	my ($a) = @_;
	my ($g, $file, $mesh, $cuts) = ($a->{'graph'}, $a->{'file'}, $a->{'mesh'}, $a->{'cuts'});
	my %n;
	my $t = $g->total_tsize($file);
	for my $e (sort keys %$mesh)
	  {
		graph_node($g, \%n, $file, $e, $cuts, $t);
		for my $f (sort {$g->unique_tsize($b) <=> $g->unique_tsize($a)} keys %{$mesh->{$e}})
		  {
			graph_node($g, \%n, $file, $f, $cuts, $t);
		  }
	  }
}

sub print_gfoot
{
	my ($a) = @_;
	print "}\n";
}

sub graph2
{
	print_ghead(@_);
	print_edges(@_);
	print_nodes(@_);
	print_gfoot(@_);
}

1;
