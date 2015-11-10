#!/usr/bin/perl

use strict;
use autodie;
use warnings FATAL => 'all';
use Cwd;
use Try::Tiny qw(try catch finally);
use Const::Fast qw(const);

const my $FILE_PAIR => '%s.%s.ngscn.bed';
const my $FILE_FOLD => '%s.%s.ngscn.fb_reads.bed';

die "Usage: genome.fa.fai sample_name indir [exclude_list]" unless(scalar @ARGV == 3);

my ($fai, $sample, $indir, $exclude) = @ARGV;
die "ERROR: *.fai file must exist with non-zero size\n" unless(-e $fai && -s _);
die "ERROR: indir must exist\n" unless(-e $indir && -d _);

my @chr_order;
open my $FAI_IN, '<', $fai;
while(<$FAI_IN>) {
  push @chr_order, (split /\t/)[0];
}
close $FAI_IN;

my $final_pair = "$indir/$sample.ngscn.bed.gz";
my $final_fold = "$indir/$sample.ngscn.fb_reads.bed.gz";

unlink $final_pair if(-e $final_pair);
unlink $final_fold if(-e $final_fold);

my $init_dir = getcwd;

my $err_code = 0;
try {
  chdir $indir;
  my $exclude_list = exclude_patterns($exclude);
  cat_to_gzip($FILE_PAIR, $final_pair, $sample, \@chr_order, $exclude_list);
  cat_to_gzip($FILE_FOLD, $final_fold, $sample, \@chr_order, $exclude_list);
} catch {
  if($_) {
    warn $_;
    $err_code = 1;
  }
} finally {
  chdir $init_dir;
};

exit $err_code;

sub exclude_patterns {
  my $patt = shift;
  my @exclude;
  return \@exclude unless($patt);
  @exclude = split /,/, $patt;
  my @exclude_patt;
  for my $ex(@exclude) {
    $ex =~ s/%/.+/;
    push @exclude_patt, $ex;
  }
  return \@exclude;
}

sub cat_to_gzip {
  my ($format, $outfile, $sample, $chrs, $exclude_list) = @_;
  my @args;
  for my $chr(@{$chrs}) {
    next if(first { $chr =~ m/^$_$/ } @{$exclude_list});
    push @args, sprintf $format, $sample, $chr if(-e $args[-1]);
    die "Expected file missing $indir/$args[-1]\n" unless(-e $args[-1]);
  }
  my $command = qq{bash -c 'set -o pipefail; cat @args | gzip -c > $outfile'};
  warn $command;
  system($command) == 0 or die "Failed to merge files to $outfile: $!\n";
}
