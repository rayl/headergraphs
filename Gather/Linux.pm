
use 5.6.0;
use strict;
use warnings;
use lib qw(.);


package Gather;

use Benchmark;
use Cwd;

use Graph;


sub new
{
	my ($type) = @_;

        # gather objects use a hash representation
        my $z = bless {}, ref $type || $type;

	# the location of the linux kernel tree
	$z->{'tree'} = "/opt/BR/src/linux";

	# the specific asm-* directories of interest.
	$z->{'arch'} =
		# "arm";
		# "i386";
		"x86_64";

	$z;
}


#
# Decide whether we want to process a header directory.
#
sub we_want_hdr_dir
{
	my ($z, $x) = @_;
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
	my ($z) = @_;
	my @d = `find . -type d -o -type l`;
	map {s/^..//} @d;
	chomp @d;
	sort grep {$z->we_want_hdr_dir($_)} @d;
}

#
# Routine to decide whether we want to process a header file
#
sub we_want_hdr_file
{
	my ($z, $x) = @_;
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
	my ($z, $d) = @_;
	sort grep {$z->we_want_hdr_file($_)} <$d/*.h>;
}

#
# Decide whether we want to process a source directory.
#
sub we_want_src_dir
{
	my ($z, $x) = @_;
	return 0 if       $x =~ m,^Documentation/,;
	return 0 if       $x =~ m,^\.git/,;
	return 0 if       $x =~ m,^include/,;
	return 0 if       $x =~ m,^scripts/,;
	return 0 if       $x =~ m,^\.tmp_versions/,;
	return 0 if       $x =~ m,^usr/,;
	return 1 unless   $x =~ m,^arch/,;
	return 0 unless   $x =~ m,^arch/$z->{'arch'}(/.*)?$,;
	return 1;
}

#
# Find all interesting source directories in the include tree
#
sub interesting_src_dirs
{
	my ($z) = @_;
	my @d = `find . -type d`;
	map {s/^..//} @d;
	chomp @d;
	sort grep {$z->we_want_src_dir($_)} @d;
}

#
# Routine to decide whether we want to process a source file
#
sub we_want_src_file
{
	my ($z, $x) = @_;
	return 1;
}

#
# Find all interesting source files in a directory
#
sub interesting_src_files
{
	my ($z, $d) = @_;
	sort grep {$z->we_want_src_file($_)} <$d/*.c>;
}

#
# Extract include lines from a file
#
sub gather
{
	my ($z, $file) = @_;

	# bail if we've already parsed this file for some reason
	my $n = $z->{'g'}->node($file);
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
		$z->{'g'}->edge($file, $h);
	  }
}

sub run
{
	my ($z) = @_;

	my ($t0, $t1);
	my $c = cwd();

	$z->{'g'} = new Graph;

	$t0 = new Benchmark;

	print "process hdrs\n";
	my $tree = $z->{'tree'};
	chdir "$tree/include" || die "Bad tree: $tree";
	map {$z->gather($_)} map {$z->interesting_hdr_files($_)} $z->interesting_hdr_dirs;
	$t1 = new Benchmark;
	print "Took " . timestr(timediff($t1, $t0)) . " seconds\n";
	$t0 = $t1;

	print "process src\n";
	chdir "$tree" || die "Bad tree: $tree";
	map {$z->gather($_)} map {$z->interesting_src_files($_)} $z->interesting_src_dirs;
	$t1 = new Benchmark;
	print "Took " . timestr(timediff($t1, $t0)) . " seconds\n";
	$t0 = $t1;

	chdir $c;

	$z->{'g'};
}

1;
