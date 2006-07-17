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

	$includes{$file} = \@incs;

	for my $x (@incs)
	  {
		$included{$x} ||= {};
		$included{$x}->{$file}++;
	  }
}


#
# Work at the top of the kernel include tree
#
chdir "$tree/include" || die "Bad tree: $tree";


#
# Gather the include lines from all files of interest.
#
map {gather $_} map {interesting_files $_} interesting_dirs;







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
		for my $i (@{$includes{$x}})
		  {
			$i =~ m,^.(.*).$,;
			my $f = $1;
	
			next if -f $f;
			next if $f eq "stdarg.h";
			next if $f =~ m,^asm/,;

			print "!! NON-EXISTENT: $x includes $i\n";
		  }
	  }
}

#----------------------------------------------------------
sub report_missingasm
{
	header "Missing ASM Files";
	for my $x (keys %includes)
	  {
		for my $i (@{$includes{$x}})
		  {
			$i =~ m,^.(.*).$,;
			my $f = $1;
	
			next if -f $f;
			next if $f eq "stdarg.h";
			next unless $f =~ m,^asm/,;
	
			print "!!  MISSING-ASM: $x includes $i\n";
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

report_double;
report_nonexistent;
report_missingasm;
repl;

