#!/bin/bash
# Script converts TI(Tigrniya) sentences in TI orthography to a sequence of IPA phones using TI lexicon.
# 
# Usage:
# > ./lorelei_create_phntrans_TI.sh  <(awk '{print $1}' tigrinya.utf8.txt) lexicon.txt tigrinya.utf8.txt
#
# The transcription file containing Tigrinya sentences (tigrinya.utf8.txt) must be in the following format:
# <utterance id>  <sentence>
# Example:
#		2017-08-08-il5ni3-001   ንጻሩ   ከም  ምስጢር 
#
# The lexicon must be in this format:
#   ንጻሩ         n ɪ ts a r u
#   ከም          k ə m
#   ምስጢር    m s tʰ i r
#
# Then, the phone transcription (output) would be the sequence of IPA phones w/o the utt id:
# n ɪ ts a r u   k ə m    m s tʰ i r


if [ $# != 3 ]; then
   echo "Usage: lorelei_create_phntrans_TI.sh [options] <uttlist> <lexicon> <transcription file>"
   exit 1;
fi

#tmpdir=/tmp/$$.tmp
tmpdir=data/TI/tmp/
mkdir -p $tmpdir

uttlist=$1
lexicon=$2
transfilein=$3

transfileout=$tmpdir/all_phn_text

local/lorelei_create_phntrans.pl -l $lexicon -i $transfilein > $transfileout

for id in `cat $uttlist`; do
	string=`cat $transfileout | grep $id| cut -d' ' -f2- `
	echo -n $string
	echo -n " "
	echo
done

#rm -rf $tmpdir
