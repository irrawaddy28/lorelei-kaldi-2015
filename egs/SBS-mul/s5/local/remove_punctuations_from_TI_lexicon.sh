#!/bin/bash
# Script removes punctuation symbols in TI(Tigrniya) orthography
# 
# Usage:
# > ./lorelei_remove_punctuations_from_TI_lexicon.sh  lexicon_with_punctuations.txt > lexicon_without_punctuations.txt
#
# Lexicon (input):
# ንልምን      n ɪ l m n ɪ
# ንልምን ።!!  n ɪ l m n ɪ
#
# Lexicon (output):
#   ንልምን      n ɪ l m n ɪ  (Punctuation symbols ።  and !! are stripped; duplicate entries created as a side-effect of removing punctuations are also removed)


if [ $# != 1 ]; then
   echo "Usage: remove_punctuations_from_TI_lexicon.sh <lexicon_in> > <lexicon_out>"
   exit 1;
fi


lexicon=$1

# Remove all Tigrinya specific punctuation symbols (like  ።)
CHARS=$(python -c 'print u"\u1360\u1361\u1362\u1363\u1364\u1365\u1366\u1367\u1368\u2010\u2011\u2012\u2013\u2014\u2015\u2016\u2017\u2018\u2019\u201A\u201B\u201C\u201D\u201E\u201F".encode("utf8")')

# Remove any other common punctuation symbols like ?'',- ; Also remove duplicate words in the lexicon 
sed 's/['"$CHARS"']//g' $lexicon | perl remove_punctuations_from_lexicon.pl -

