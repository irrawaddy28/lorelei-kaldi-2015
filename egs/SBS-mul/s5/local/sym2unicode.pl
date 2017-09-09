#!/usr/bin/perl
# =====================================================================
# Print unicode codepoints in hex given a unicode symbol
# 
# Input: A single unicode symbol (e.g. æ) or a composition of symbols (e.g. d͡ʒʱ)
#
# Output: Unicode codepoint(s) associated with the unicode symbol(s).
# 
# References:
# IPA to Unicode Table: http://www.phon.ucl.ac.uk/home/wells/ipa-unicode.htm#spac
# IPA to Unicode Chart: http://westonruter.github.io/ipa-chart/keyboard/
# Unicode Codepoints and Symbols: http://unicode-table.com/en/
# =====================================================================
# Usage: > perl sym2unicode.pl æ
# 		   æ : 0xe6
#        > perl sym2unicode.pl  d͡ʒʱ
#		   d ͡ ʒ ʱ : 0x64 0x361 0x292 0x2b1
#		   
# Usage: CLI version of this script:
# > echo "æ"| perl -ane 'use Encode qw(encode decode); chomp $_; my @unicode_txt = split(//, decode("utf-8", $_)); @unicode_hex = map {sprintf("0x%x", ord($_))} @unicode_txt;    $sym = encode("utf-8", "@unicode_txt"); print "$sym  : @unicode_hex\n";'
#
# æ  : 0xe6

use Encode qw(encode decode);
use open ':std', ':encoding(UTF-8)';

(@ARGV == 1) || die "Usage: perl $0 ab \n";

# convert unicode byte string to text string.
my @unicode_txt = split(//, decode("utf-8", $ARGV[0]));

my $n = @unicode_txt;
# print "num syms = $n\n";
# foreach (@unicode_txt) { print "split = $_\n";}

# find the hex equivalent of each symbol present in the text string	
@unicode_hex = map {sprintf("0x%x", ord($_))} @unicode_txt;
print "@unicode_txt : @unicode_hex\n";
