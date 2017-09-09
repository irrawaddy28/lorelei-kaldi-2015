#!/usr/bin/perl -w

# Copyright 2012  Arnab Ghoshal

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.


# This script takes a lexicon (mapping orthography to IPA phones) and removes all punctuations present within words.
# It'll also remove any duplicate words.
# E.g.
# Lexicon (input):
# ንልምን      n ɪ l m n ɪ
# ንልምን ።!!  n ɪ l m n ɪ
#
# Lexicon (output):
#   ንልምን      n ɪ l m n ɪ  (Punctuation symbols ።  and !! are stripped and duplicate word removed)
#

my $usage = "Usage: perl remove_punctuations_from_leixcon.pl lexicon_in.txt > lexicon_out.txt\n";

use strict;
die "$usage" unless(@ARGV >= 1);
my ($in_lex) = @ARGV;

# Create a hash table with words mapped to pronunciations
open(L, "<$in_lex") or die "Cannot open lexicon file '$in_lex': $!";
my (%lex, @order);
my $num_seen_words = 0;
while (<L>) {
  s/\r//g;  # Since files may have CRLF line breaks!
  chomp;
  next if($_=~/\#/);  # Usually incomplete or empty prons
  $_ =~ m:^\{?(\S*?)\}?\s+\{?(.+?)\}?$: or die "Bad line: $_";
  my $word = $1;
  my $pron = $2;
  
  $word =~ s/^\s*//; $word =~ s/\s*$//;  # Normalize spaces  
  $word =~ s/[\(\)]//g;     # Remove left & right parantheses ( )
  $word =~ s/[!-:\?"]*//g;  # Remove punctuations  
  
  if (!defined($lex{$word})) {
    $lex{$word} = $pron;
    push @order, $word;
    $num_seen_words += 1;
  }
}
#print "Num words = $num_seen_words\n";
foreach my $key (@order) {
	print "$key $lex{$key}\n";
}

