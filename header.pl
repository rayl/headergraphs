#!/usr/bin/perl

use 5.6.0;
use strict;
use warnings;

my $tree = "/home/rayl/proj/linux";
my $arch = "arm";
my $mach = "ep93xx";



#
# Work in the linux/include directory
#
chdir "$tree/include" || die "Bad tree: $tree";

#
# Find all symlinks in the include tree
#
my @links = `find . -type l`;
map {s/^..//} @links;
chomp @links;

#
# Create a map for the directory filter.
#
my %link;
for my $link (@links)
  {
	$link{$link} = readlink $link;
  }

#
# Print the map for the user
#
print "Symbolic links:\n";
print "  $_ -> $link{$_}\n" for sort keys %link;

#
# Find all directories in the include tree
#
my @incdirs = `find . -type d`;
map {s/^..//} @incdirs;
chomp @incdirs;

#
# Routine to decide whether we want to process a directory. The
# asm heuristic is imperfect, but should work for i386, arm, mips,
# and cris, at least...
#
sub we_want_dir
{
	my ($x) = @_;

	return 0 if       $x =~ m,^config,;
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
	return 0 if $x =~ m,^asm-.*/asm-offsets.h,;
	return 0 if $x =~ m,^linux/autoconf.h,;
	return 0 if $x =~ m,^linux/compile.h,;
	return 0 if $x =~ m,^linux/version.h,;
	return 1;
}

for my $dir (sort @incdirs)
  {
	next unless we_want_dir $dir;
	for my $file (sort <$dir/*.h>)
	  {
		next unless we_want_file $file;
	  }
  }


__END__

# create "includes" map (file -> [file])
# create "included" map (file -> [file])

