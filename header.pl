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
	("i386",  "generic");





# Who do we include?
my %includes;

# Who includes us?
my %included;






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

	open F, "<$file" || die "Can't read $file!";
	my @incs = grep {s,^\s*#\s*include\s*(["<][^>"]*[">]).*,$1,} <F>;
	chomp @incs;
	close F;

	$includes{$file} = \@incs;

	for my $x (@incs)
	  {
		$included{$x} ||= [];
		push @{$included{$x}}, $file;
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


#
# Compact the %included arrays, warning about double inclusions.
#
for my $x (keys %included)
  {
	my %u;
	map { $u{$_}++ } @{$included{$x}};
	map { print "$_ includes $x $u{$_} times\n" if $u{$_} > 1 } keys %u;
	$included{$x} = [keys %u];
  }

