#!/bin/bash
# This script takes word transcriptions (in Tigrinya orthography) and removes all OOVs and punctuations.
# 
# Usage:
# > ./lorelei_create_wrdtrans_TI.sh  <(awk '{print $1}' tigrinya.utf8.txt) lexicon.txt  tigrinya.utf8.txt
#
# The transcription file containing Tigrinya sentences (tigrinya.utf8.txt) must be in the following format:
# <utterance id>  <sentence>
# Example:
#		2017-08-08-il5ni3-001   ንጻሩ  " ከም "   ምስጢር !
#
# The lexicon must be in this format:
#   ንጻሩ         n ɪ ts a r u#
#   ምስጢር    m s tʰ i r
#
# Then, the word transcription (output) would be words w/o OOVs and punctuations:
#   ንጻሩ       ምስጢር

if [ $# != 3 ]; then
   echo "Usage: lorelei_create_wrdtrans_TI.sh [options] <uttlist> <lexicon> <transcription file>"
   exit 1;
fi

#tmpdir=/tmp/$$.tmp
tmpdir=data/TI/tmp/
mkdir -p $tmpdir

uttlist=$1
lexicon=$2
transfilein=$3

transfileout=$tmpdir/all_wrd_text

local/lorelei_create_wrdtrans.pl -l $lexicon -i $transfilein > $transfileout

for id in `cat $uttlist`; do
	string=`cat $transfileout | grep $id| cut -d' ' -f2- `
	echo -n $string
	echo -n " "
	echo
done

#rm -rf $tmpdir
