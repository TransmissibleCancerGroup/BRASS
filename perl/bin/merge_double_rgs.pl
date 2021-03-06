#!/usr/bin/perl

########## LICENCE ##########
# Copyright (c) 2014-2016 Genome Research Ltd.
#
# Author: Cancer Genome Project <cgpit@sanger.ac.uk>
#
# This file is part of BRASS.
#
# BRASS is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation; either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# 1. The usage of a range of years within a copyright statement contained within
# this distribution should be interpreted as being equivalent to a list of years
# including the first and last year specified and all consecutive years between
# them. For example, a copyright statement that reads ‘Copyright (c) 2005, 2007-
# 2009, 2011-2012’ should be interpreted as being identical to a statement that
# reads ‘Copyright (c) 2005, 2007, 2008, 2009, 2011, 2012’ and a copyright
# statement that reads ‘Copyright (c) 2005-2012’ should be interpreted as being
# identical to a statement that reads ‘Copyright (c) 2005, 2006, 2007, 2008,
# 2009, 2010, 2011, 2012’."
########## LICENCE ##########

use FindBin;
use lib "$FindBin::Bin/../lib";

use strict;
use warnings;
use List::Util qw(min max);
use Const::Fast qw(const);
use Capture::Tiny qw(capture);

use Sanger::CGP::Brass::Implement;

const my $SLOP => 300;

if (@ARGV == 0) {
  print STDERR <<EOF;

  Usage:
    perl merge_double_rgs.pl input.bedpe [output.filtered.bedpe]

EOF

  exit 1;
}

my $in_file = $ARGV[0];
my $bedtools = Sanger::CGP::Brass::Implement::_which('bedtools');
my $command = sprintf q{bash -c 'set -o pipefail; cut -f-10 %s | bedtools pairtopair -a stdin -b %s -slop %d -rdn'}, $in_file, $in_file, $SLOP;
my ($stdin, $stderr, $exit) = capture{ system($command); };
if($exit) {
  die "\nFATAL: $stderr\n\tWhile executing: $command\n\n";
}
my @lines = split "\n", $stdin;

my %id_overlaps_with;
my %data_of_id;
for (@lines) {
  chomp;
  my @F = split /\t/;
  push @{$id_overlaps_with{$F[16]}}, [$F[6], $F[7]];
  $data_of_id{$F[16]} = [@F[10..$#F]];
}

my %to_be_excluded;
for my $id (keys %id_overlaps_with) {
  for (@{$id_overlaps_with{$id}}) {
    if ($data_of_id{$id}->[7] < $_->[1] || ($data_of_id{$id}->[7] == $_->[1] && $id gt $_->[0])) {
      $to_be_excluded{$id} = 1;
      delete $id_overlaps_with{$id};
      last;
    }
  }
}

my $fh;
if(@ARGV == 2) {
  open $fh, '>', $ARGV[1] || die "Failed to create $ARGV[1]: $!\n";
}
else {
  $fh = *STDOUT;
}

# Now the remaining ids in %id_overlaps_with are the ones to keep.
open my $IN, $in_file or die $!;
while (<$IN>) {
  chomp;
  my @F = split /\t/;
  my $id = $F[6];

  if (exists($to_be_excluded{$id})) {
    next;
  }
  elsif (exists($id_overlaps_with{$id})) {
    $F[1] = min($F[1], map { $data_of_id{$_->[0]}->[1] } @{$id_overlaps_with{$id}});
    $F[2] = max($F[2], map { $data_of_id{$_->[0]}->[2] } @{$id_overlaps_with{$id}});
    $F[4] = min($F[4], map { $data_of_id{$_->[0]}->[4] } @{$id_overlaps_with{$id}});
    $F[5] = max($F[5], map { $data_of_id{$_->[0]}->[5] } @{$id_overlaps_with{$id}});
  }

  print $fh join("\t", @F) . "\n";
}
close $IN;

close $fh if(@ARGV == 2);

