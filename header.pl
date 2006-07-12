#!/usr/bin/perl

use 5.6.0;
use strict;
use warnings;

# the location of the linux kernel tree
my $tree = "/home/rayl/proj/linux";

# the specific asm-* directories of interest.
# the heuristic used by we_want_dir() is imperfect, but
# should be adequate for i386, arm, mips, and cris, at least...
my $arch = "arm";
my $mach = "ep93xx";




#
# Work in the linux/include directory
#
chdir "$tree/include" || die "Bad tree: $tree";

#
# Find all directories in the include tree
#
my @incdirs = `find . -type d`;
map {s/^..//} @incdirs;
chomp @incdirs;

#
# Routine to decide whether we want to process a directory.
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
# Who do we include?  header -> [ child_header ]
#
my %includes;

#
# Who includes us?    header -> [ parent_header ]
#
my %included;


#
# A routine to extract include lines from a header file
#
sub gather
{
	my ($file) = @_;

	open F, "<$file" || die "Can't read $file!";
	my @incs = grep {s,^\s*#\s*include\s*(["<][^>"]*[">]).*,$1,} <F>;
	close F;

	chomp @incs;
	$includes{$file} = \@incs;

	for my $x (@incs)
	  {
		$included{$x} ||= [];
		push @{$included{$x}}, $file;
	  }
}


#
# Gather the include lines from all interesting header files.
#
for my $dir (sort @incdirs)
  {
	next unless we_want_dir $dir;
	for my $file (sort <$dir/*.h>)
	  {
		next unless we_want_file $file;
		gather($file);
	  }
  }

#
# Warn about double inclusion.
#
sub doubleinc
{
	my ($f, $h, $n) = @_;
	warn "$f includes $h $n times.";
}

#
# Compact the %included arrays, warning about double inclusions.
#
for my $x (keys %included)
  {
	my %u;
	map { $u{$_}++ } @{$included{$x}};
	map { my $n = $u{$_}; doubleinc($_, $x, $n) if $n > 1 } keys %u;
	$included{$x} = [keys %u];
  }




__END__

# create "includes" map (file -> [file])
# create "included" map (file -> [file])

