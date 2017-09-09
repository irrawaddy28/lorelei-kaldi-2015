#!/bin/bash -u

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

set -o errexit

function error_exit () {
  printf "$@\n" >&2; exit 1;
}

function read_dirname () {
  [ -d "$1" ] || error_exit "Argument '$1' not a directory";
  local retval=`cd $1 2>/dev/null && pwd || exit 1`
  echo $retval
}

. ./path.sh    # Sets the PATH to contain necessary executables

# Begin configuration section.
config_dir=conf    #
# end configuration sections

PROG=`basename $0`;
help_message="Usage: "`basename $0`" [options] LC [LC ... ]
where LC is a 2-letter code for SBS languages (e.g. MD for Mandarin).\n
options: 
  --help                # print this message and exit
  --config-dir DIR      # directory to find config files (default: $config_dir)
";

#. utils/parse_options.sh

if [ $# -lt 1 ]; then
  printf "$help_message\n"; exit 1;
fi

LANGUAGES=
while [ $# -gt 0 ]; do
  case "$1" in
  ??) LANGUAGES=$LANGUAGES" $1"; shift ;;
  --pow=*)
  POW=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; error_exit "$help_message" ;;
  esac
done

[ -f path.sh ] && . path.sh  # Sets the PATH to contain necessary executables


# (1) Create the dictionary
for L in $LANGUAGES; do
  srcdir=data/$L/local/data
  printf "Language - ${L}: preparing pronunciation lexicon ... "
  mkdir -p data/$L/local/dict
  full_name=`awk '/'$L'/ {print $2}' $config_dir/lang_codes.txt`;
  mkdir -p conf/${full_name}
  phones=$config_dir/$full_name/phones.txt
  
  if [[ $POW == "p" ]]; then
  	# create phone list w/o sil, spn
  	cut -f2- $srcdir/train_text | tr ' ' '\n' |LC_ALL=C sort -u > $phones
  	# create lexicon w/o sil, spn
  	awk '{print $1"\t"$1}' $phones > data/$L/local/dict/lexicon_nosil.txt
  	# create lexicon w/ sil, spn
    (printf '!SIL\tsil\n<unk>\tspn\n';) \
      | cat - data/$L/local/dict/lexicon_nosil.txt \
     > data/$L/local/dict/lexicon.txt;
  elif [[ $POW == "w" ]]; then
  	 # create lexicon w/ sil, spn
     mv data/$L/local/data/lexicon.txt data/$L/local/dict
     # create lexicon w/o sil, spn
     cat data/$L/local/dict/lexicon.txt | grep -v 'sil\|spn' > data/$L/local/dict/lexicon_nosil.txt
     # create phone list w/o sil, spn
     cut -d' ' -f2- data/$L/local/dict/lexicon.txt | grep -v 'sil\|spn'| tr ' ' '\n' |LC_ALL=C sort -u > $phones
  else
    echo "Unkown POW = $POW" && exit 1;
  fi
  echo "Done"

  printf "Language - ${L}: extracting phone lists ... "
  # silence phones, one per line.
  { echo sil; echo spn; } > data/$L/local/dict/silence_phones.txt
  echo sil > data/$L/local/dict/optional_silence.txt
  cat data/$L/local/dict/lexicon_nosil.txt | awk '{$1=""; print $0}'|sed 's/^ *//g'|tr ' ' '\n'|LC_ALL=C sort -u \
    > data/$L/local/dict/nonsilence_phones.txt
  # Ask questions about the entire set of 'silence' and 'non-silence' phones.
  # These augment the questions obtained automatically by clustering.
  ( tr '\n' ' ' < data/$L/local/dict/silence_phones.txt; echo;
    tr '\n' ' ' < data/$L/local/dict/nonsilence_phones.txt; echo;
    ) > data/$L/local/dict/extra_questions.txt
  echo "Done"
done

srcdir=data/local/data
printf "preparing pronunciation lexicon for universal set ... "
mkdir -p data/local/dict
phones=$config_dir/phones.txt
# cut -f2- $srcdir/train_text | tr ' ' '\n' | sort -u > $phones
awk '{print $1}' conf/univphones.txt | grep -v '#0' | grep -v '<eps>' > $phones

awk '{print $1"\t"$1}' $phones > data/local/dict/lexicon_nosil.txt

(printf '!SIL\tsil\n<unk>\tspn\n';) \
  | cat - data/local/dict/lexicon_nosil.txt \
  > data/local/dict/lexicon.txt;
echo "Done"

printf "extracting phone lists ... "
# silence phones, one per line.
{ echo sil; echo spn; } > data/local/dict/silence_phones.txt
echo sil > data/local/dict/optional_silence.txt
cut -f2- data/local/dict/lexicon_nosil.txt | tr ' ' '\n' |LC_ALL=C sort -u \
  > data/local/dict/nonsilence_phones.txt
# Ask questions about the entire set of 'silence' and 'non-silence' phones. 
# These augment the questions obtained automatically by clustering. 
( tr '\n' ' ' < data/local/dict/silence_phones.txt; echo;
  tr '\n' ' ' < data/local/dict/nonsilence_phones.txt; echo;
  ) > data/local/dict/extra_questions.txt
echo "Done"

echo "Finished dictionary preparation."
