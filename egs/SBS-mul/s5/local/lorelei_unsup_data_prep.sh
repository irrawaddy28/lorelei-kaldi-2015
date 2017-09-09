#!/bin/bash -u
# Adapted from egs/gp/local/gp_data_prep.sh

set -o errexit

function error_exit () {
  echo -e "$@" >&2; exit 1;
}

function read_dirname () {
  local dir_name=`expr "X$1" : '[^=]*=\(.*\)'`;
  [ -d "$dir_name" ] || error_exit "Argument '$dir_name' not a directory";
  local retval=`cd $dir_name 2>/dev/null && pwd || exit 1`
  echo $retval
}

PROG=`basename $0`;
usage="Usage: $PROG <arguments>\n
Prepare train, dev, eval file lists for a language.\n
e.g.: $PROG --config-dir=conf --corpus-dir=corpus --languages=\"AR HU SW\" --trans-dir=transcripts --list-dir=lists\n\n
Required arguments:\n
  --config-dir=DIR\tDirecory containing the necessary config files\n
  --corpus-dir=DIR\tDirectory containing the SBS audio corpus\n
  --list-dir=DIR\tDirectory containing the train/eval splits for all languages\n
  --trans-dir=DIR\tDirectory containing all the SBS matched transcripts\n
  --languages=STR\tSpace separated list of two letter language codes\n
";

if [ $# -lt 5 ]; then
  error_exit $usage;
fi

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --config-dir=*)
  CONFDIR=`read_dirname $1`; shift ;;
  --corpus-dir=*)
  CORPUSDIR=`read_dirname $1`; shift ;;
  --unsup-name=*)
  UNSUPNAME=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --list-dir=*)
  LISTDIR=`read_dirname $1`; shift ;;
  --languages=*)  
  LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;  
  ??) LCODE=$1; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

# (1) Check if config files are in place
pushd $CONFDIR > /dev/null
[ -f lang_codes.txt ] || error_exit "$PROG: Mapping for language name to 2-letter code not found.";

popd > /dev/null
[ -f path.sh ] && . path.sh  # Sets the PATH to contain necessary executables

LANGMAP=$CONFDIR/lang_codes.txt
full_name=`awk '/'$LCODE'/ {print $2}' $LANGMAP`;

LISTFILE=$LISTDIR/${full_name}/$UNSUPNAME
LISTFILE=`echo ${LISTFILE}.txt`

echo $LISTFILE
num_unsup_files=$(cat $LISTFILE| wc -l)
if [[ $num_unsup_files -eq 0 ]]; then
    echo "No utterances found in $LISTFILE" && exit 1
fi

name=$UNSUPNAME  # name of unsup data dir

tmpdir=data/$LCODE/tmp_$name
mkdir -p $tmpdir
rm -rf $tmpdir/*

mkdir -p conf/${full_name}

for x in $name; do

    echo "Prepare wav scp: $LCODE, $x"
    file="$LISTFILE"
    
    cat $file| sed 's:.wav$::' | sort -k1,1 > $tmpdir/${x}_basenames_wav
    cat $tmpdir/${x}_basenames_wav | awk -v d=$CORPUSDIR/${full_name}/${name} '{ print d"/"$1".wav"}' >  $tmpdir/${x}_wav
    paste $tmpdir/${x}_basenames_wav $tmpdir/${x}_wav | sort -k1,1 > data/${LCODE}/local/data/${x}_wav.scp
    
    if [[ $LCODE == "TI" ]]; then
      sed 's/-.*$//' $tmpdir/${x}_basenames_wav | paste -d' ' $tmpdir/${x}_basenames_wav - | sort -t' ' -k1,1  > data/${LCODE}/local/data/${x}_utt2spk
    else
      echo "$LCODE not supported"
      exit 1
    fi
    ./utils/utt2spk_to_spk2utt.pl data/${LCODE}/local/data/${x}_utt2spk > data/${LCODE}/local/data/${x}_spk2utt || exit 1;

done
# (3) Creating final directories to contain training/test files

for L in $LANGUAGES; do
    echo "Language $L: Building data..."

    #for x in train dev eval; do
    for x in $name; do
        mkdir -p data/$L/$x
        cp data/$L/local/data/${x}_wav.scp data/$L/$x/wav.scp
        #cp data/$L/local/data/${x}_text data/$L/$x/text
        cp data/$L/local/data/${x}_utt2spk data/$L/$x/utt2spk
        cp data/$L/local/data/${x}_spk2utt data/$L/$x/spk2utt
    done
    echo "Done."
done

echo "Finished data preparation."
