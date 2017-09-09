#!/bin/bash -u

set -o errexit
set -o pipefail

function read_dirname () {
  local dir_name=`expr "X$1" : '[^=]*=\(.*\)'`;
  [ -d "$dir_name" ] || { echo "Argument '$dir_name' not a directory" >&2; \
    exit 1; }
  local retval=`cd $dir_name 2>/dev/null && pwd || exit 1`
  echo $retval
}

PROG=`basename $0`;
usage="Usage: $PROG <arguments> <2-letter language code>\n
Prepare train, test file lists for an SBS language.\n\n
Required arguments:\n
  --corpus-dir=DIR\tDirectory for the SBS (matched) corpus\n
  --trans-dir=DIR\tDirectory containing the matched transcripts for all languages\n
  --list-dir=DIR\tDirectory containing the train/eval split for all languages\n
  --lang-map=FILE\tMapping from 2-letter language code to full name\n
  --eng-ipa-map=FILE\tMapping from English phones in ARPABET to IPA phones\n
  --eng-dict=FILE\tEnglish dictionary file (e.g. CMUdict)\n
";

if [ $# -lt 8 ]; then
  echo -e $usage; exit 1;
fi

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --corpus-dir=*) 
  CORPUSDIR=`read_dirname $1`; shift ;;
  --trans-dir=*)
  TRANSDIR=`read_dirname $1`; shift ;;
  --lex-dir=*)
  LEXDIR=`read_dirname $1`; shift ;;
  --list-dir=*)  
  LISTDIR=`read_dirname $1`; shift ;;
  --pow=*)
  POW=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --lang-map=*)
  LANGMAP=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --eng-ipa-map=*)
  ENGMAP=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --eng-dict=*)
  ENGDICT=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  ??) LCODE=$1; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

[ -f path.sh ] && . path.sh  # Sets the PATH to contain necessary executables

full_name=`awk '/'$LCODE'/ {print $2}' $LANGMAP`;

num_train_files=$(wc -l $LISTDIR/$full_name/train.txt | awk '{print $1}')
num_eval_files=$(wc -l  $LISTDIR/$full_name/eval.txt | awk '{print $1}')

if [[ $num_train_files -eq 0 || $num_eval_files -eq 0 ]]; then
    echo "No utterances found in $LISTDIR/$full_name/train.txt OR $LISTDIR/$full_name/eval.txt" && exit 1
fi
# Checking if sox is installed
#which sox > /dev/null

#mkdir -p data/$LCODE/wav # directory storing all the downsampled WAV files

#tmpdir=$(mktemp -d);
#trap 'rm -rf "$tmpdir"' EXIT
tmpdir=data/$LCODE/tmp
mkdir -p $tmpdir
rm -rf $tmpdir/*

mkdir -p conf/${full_name}

cat $TRANSDIR/${full_name}/${full_name}.utf8.txt|awk '{print $1}' | sort -k1,1 > $tmpdir/all_basenames_wav

#for x in train dev $eval; do
for x in train eval; do

    echo "Prepare wav scp: $LCODE, $x"
    file="$LISTDIR/$full_name/$x.txt"
        
    # For some corpora, the number of transcribed utts provided is less than the number of audio files. 
    # Thus, we discard the audio files which do not have corresp transcribed data
    comm -12  <(cat $file| sed 's:.wav$::' | sort -k1,1)  $tmpdir/all_basenames_wav  > $tmpdir/${x}_basenames_wav # find uttids common b/w wave files and transcriptions
    cat $tmpdir/${x}_basenames_wav | awk -v d=$CORPUSDIR/$full_name/${x} '{ print d"/"$1".wav"}' >  $tmpdir/${x}_wav
    paste $tmpdir/${x}_basenames_wav $tmpdir/${x}_wav | sort -k1,1 > data/${LCODE}/local/data/${x}_wav.scp
    
    if [[ $LCODE == "TI" ]]; then
      sed 's/\(.*\)\-.*$/\1/' $tmpdir/${x}_basenames_wav | paste -d' ' $tmpdir/${x}_basenames_wav - | sort -t' ' -k1,1  > data/${LCODE}/local/data/${x}_utt2spk
    else
      echo "$LCODE not supported"
      exit 1
    fi    
    ./utils/utt2spk_to_spk2utt.pl data/${LCODE}/local/data/${x}_utt2spk > data/${LCODE}/local/data/${x}_spk2utt || exit 1;

    # Processing transcripts
    # first, map English words in transcripts to their IPA pronunciations
    if [[ $LCODE != "AM" && $LCODE != "DI" && $LCODE != "TI" ]]; then
      echo "Preprocess English"
      ./local/sbs_english_filter.pl --ipafile $ENGMAP --dictfile $ENGDICT --utts "$tmpdir/downsample/${x}_basenames_wav" --idir "$TRANSDIR/${full_name}" --odir $tmpdir/trans
    else
      echo "English filter not reqd. for $LCODE"
    fi    

    echo "Generating $POW transcriptions for $LCODE in data/${LCODE}/local/data/${x}_text ..."
    #################################################
    #### LANGUAGE SPECIFIC TRANSCRIPT PROCESSING ####
    # This script could take as arguments:
    # 1. the list of utterance IDs ($tmpdir/downsample/${x}_basenames_wav)
    # 2. the grapheme to phoneme mapping for the target language (available either in the 2-column format or as an FST)
    # 3. directory containing all the matched transcripts ($TRANSDIR)
    
    case "$LCODE" in
        AR)
            local/ar_to_ipa.sh --utts $tmpdir/downsample/${x}_basenames_wav --transdir "$TRANSDIR/${full_name}" | LC_ALL=en_US.UTF-8 local/uniphone.py | sed 's/SIL//g' | sed 's/   */ /g' | sed 's/^ *//g' | sed 's/ *$//g' > $tmpdir/${LCODE}_${x}.trans 
            ;;
        DT)
            local/dt_to_ipa.sh --utts $tmpdir/downsample/${x}_basenames_wav --transdir "$TRANSDIR/${full_name}" | LC_ALL=en_US.UTF-8 local/uniphone.py | sed 's/SIL//g' | sed 's/   */ /g' | sed 's/^ *//g' | sed 's/ *$//g' > $tmpdir/${LCODE}_${x}.trans
            ;;
        MD)
            sed 's:wav:txt:g' $LISTDIR/${full_name}/${x}.txt | sed "s:^:${TRANSDIR}/${full_name}/:" | LC_ALL=en_US.UTF-8 xargs local/MD_seg.py conf/${full_name}/callhome-dict | LC_ALL=en_US.UTF-8 local/uniphone.py > $tmpdir/${LCODE}_${x}.trans
            ;;
        HG)
            local/sbs_create_phntrans_HG.py --g2p conf/${full_name}/g2pmap.txt --utts $tmpdir/downsample/${x}_basenames_wav --transdir "$TRANSDIR/${full_name}" | LC_ALL=en_US.UTF-8 local/uniphone.py | sed 's/sil//g' | sed 's/   */ /g' | sed 's/^ *//g' | sed 's/ *$//g'> $tmpdir/${LCODE}_${x}.trans 
            ;;
        SW)
            local/sbs_create_phntrans_SW.pl --g2p conf/${full_name}/g2pmap.txt --utts $tmpdir/downsample/${x}_basenames_wav --transdir $tmpdir/trans --wordlist conf/${full_name}/wordlist.txt | LC_ALL=en_US.UTF-8 local/uniphone.py > $tmpdir/${LCODE}_${x}.trans
            ;;
        UR)
            local/sbs_create_phntrans_UR.sh $tmpdir/downsample/${x}_basenames_wav conf/${full_name}/g2pmap.txt $TRANSDIR/${full_name} | LC_ALL=en_US.UTF-8 local/uniphone.py | sed 's/eps//g' | sed 's/   */ /g' | sed 's/^ *//g' | sed 's/ *$//g' > $tmpdir/${LCODE}_${x}.trans
            ;;
        CA)
            local/sbs_create_phntrans_CA.py --utts $tmpdir/downsample/${x}_basenames_wav --transdir "$TRANSDIR/${full_name}" | sed 's/g/ɡ/g' | LC_ALL=en_US.UTF-8 local/uniphone.py | sed 's/ *sil */ /g' | sed 's/  \+/ /g' | sed 's/ \+$//g' | sed 's/^ \+//g' > $tmpdir/${LCODE}_${x}.trans
            ;;
        AM)
						local/sbs_create_phntrans_AM.sh $tmpdir/downsample/${x}_basenames_wav conf/${full_name}/g2pmap.txt $TRANSDIR/${full_name}/${full_name}.utf8.txt | LC_ALL=en_US.UTF-8 local/uniphone.py > $tmpdir/${LCODE}_${x}.trans
						;;
				DI)
						local/sbs_create_phntrans_DI.sh $tmpdir/downsample/${x}_basenames_wav conf/${full_name}/g2pmap.txt $TRANSDIR/${full_name}/${full_name}.utf8.txt | LC_ALL=en_US.UTF-8 local/uniphone.py > $tmpdir/${LCODE}_${x}.trans
						;;
				TI)	
						if [[ $POW == "p" ]]; then
						  local/lorelei_create_phntrans_TI.sh $tmpdir/${x}_basenames_wav $LEXDIR/${full_name}/lexicon.txt $TRANSDIR/${full_name}/${full_name}.utf8.txt | LC_ALL=en_US.UTF-8 local/uniphone.py > $tmpdir/${LCODE}_${x}.trans
						else [[ $POW == "w" ]];
						  local/lorelei_create_wrdtrans_TI.sh $tmpdir/${x}_basenames_wav $LEXDIR/${full_name}/lexicon.txt $TRANSDIR/${full_name}/${full_name}.utf8.txt > $tmpdir/${LCODE}_${x}.trans
						  cp $LEXDIR/${full_name}/lexicon.txt data/${LCODE}/local/data
						fi
						;;
        *)
            echo "Unknown language code $LCODE." && exit 1
    esac
    #################################################
    
    paste $tmpdir/${x}_basenames_wav $tmpdir/${LCODE}_${x}.trans | sort -k1,1 > data/${LCODE}/local/data/${x}_text    
    
done

