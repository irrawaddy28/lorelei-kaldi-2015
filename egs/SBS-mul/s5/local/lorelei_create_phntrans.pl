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


# This script converts word transcriptions (in language L's orthography) into phone transcriptions by using a lexicon.
# It'll ignore the (OOVs), i.e. any word in the transcription that is not present in the lexicon is ignored.
# E.g.
# Word transcription (input):
# 2017-08-08-il5ni3-001   ንጻሩ   ከም  ምስጢር 
#
# Lexicon (input):
#   ንጻሩ         n ɪ ts a r u
#   ከም          k ə m
#  ምስጢር    m s tʰ i r
#
# Phone transcription (output):
# 2017-08-08-il5ni3-001    n ɪ ts a r u   k ə m    m s tʰ i r

my $usage = "Usage: perl lorelei_create_phntrans.pl -i word_transcription.txt -l lexicon.txt > phone_transcription.txt\n
converts word transcriptions (in language L's orthography) into phone transcriptions by using a lexicon.
The lexicon for language L defines a mapping between words and IPA phones.\n";

use strict;
use Getopt::Long;
die "$usage" unless(@ARGV >= 1);
my ($in_trans, $in_lex);
GetOptions ("i=s" => \$in_trans,    # Input transcription
	          "l=s" => \$in_lex);     # Input lexicon
	          
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
  if (!defined($lex{$word})) {
    $lex{$word} = $pron;
    push @order, $word;
    $num_seen_words += 1;
  }
}
#print "Num words = $num_seen_words\n";
#foreach my $key (@order) {
#	print "$key $lex{$key}\n";
#}


open(T, "<$in_trans") or die "Cannot open transcription file '$in_trans': $!";
my (%oov);
while (<T>) {
  chomp;
  $_ =~ m:^(\S+)\s+(.+): or die "Bad line: $_";
  my $utt_id = $1;
  my $trans = $2; # $trans contains a seq of words
  
  $trans =~ s/^\s*//; $trans =~ s/\s*$//;  # Normalize spaces
  #$trans =~ s/\([^)]*\)//g; # Remove text within parantheses
  $trans =~ s/[\(\)]//g;     # Remove left & right parantheses ( )
  $trans =~ s/[!-:\?"]*//g;  # Remove punctuations  
  #print "$utt_id  $trans\n";
  
  print $utt_id;
  for my $word (split(/\s+/, $trans)) {
    if(exists $lex{$word}){
			print " $lex{$word}";
		} else {
			if (!defined($oov{$word})) {
				$oov{$word} = 1;
			} else {
				$oov{$word} += 1;
			}
			#print "\nCannot find pronunciation for $utt_id -> $word\n";
			#die "";
		} 
  }
  print "\n";
}

# If you want to know the OOVs and the number of occurences of each OOV.
# print "==OOV==\n";
# print "$_ \t $oov{$_}\n" for keys %oov;
