#!/bin/bash -e

# This script shows the steps needed to build a recognizer for certain matched languages (Arabic, Dutch, Mandarin, Hungarian, Swahili, Urdu) of the SBS corpus. 
# (Adapted from the egs/gp script run.sh)

echo "This shell script may run as-is on your system, but it is recommended 
that you run the commands one by one by copying and pasting into the shell."
#exit 1;

[ -f cmd.sh ] && source ./cmd.sh \
  || echo "cmd.sh not found. Jobs may not execute properly."

. path.sh || { echo "Cannot source path.sh"; exit 1; }


stage=0
pow=p # phone or word
graph_affix="" # if you want to decode the test data using LMs built from 
			   # text data taken from:
			   # SBS train set, set graph_affix to "" (supported)
			   # wiki, set graph_affix to "_text_G" (not supported yet)
decode_only=false
unsup=   # "eval2" for Tigrinya
# End of config


# Usage
# > ./run_hmm_monolingual_lorelei.sh [options] <language code>
# options:
# --stage <num> 
# --unsup <string> (name of an evaluation set you want to decode but this set does not have any ground truth transcriptions. It assumes you already have a trained model that will do the decoding.)
# --decode-only <true|false>  (skip training. Go straight to tri3b model and decode $unsup)
# --pow <p|w> (p = train phone ASR, w = train word ASR)
#
# E.g. 1.
# Train a phone based ASR in Tigrinya (TI)
# > ./run_hmm_monolingual_lorelei.sh --stage 0 --decode-only "false" --pow "p" TI
# Test the phone based ASR on an unsupervised data (where unsup=eval2)
# > ./run_hmm_monolingual_lorelei.sh --stage 2 --unsup=eval2 --decode-only "true" --pow "p" TI
#
# E.g. 2.
# Train a phone based ASR in Tigrinya (TI) and also test on unsup
# > ./run_hmm_monolingual_lorelei.sh --stage 0 --unsup=eval2  --decode-only "false" --pow "p" TI
#
# More on unsup:
# What does unsup=eval2 mean?
# If your audio files for unsup data is stored in a dir like this: /ws/data/audio/tigrinya/eval2/*.wav, then
# you simply assign the directory name (eval2) to unsup.
#
			   
# Set the location of the SBS speech 
CORPUS=${DATADIR}/audio
TRANSCRIPTS=${DATADIR}/transcripts/matched
LEXICON=${DATADIR}/lexicon
DATA_LISTS=${DATADIR}/lists
TEXT_PHONE_LM=${DATADIR}/text-phnlm
NUMLEAVES=1200
NUMGAUSSIANS=8000

echo "$0 $@"  # Print the command line for logging

. utils/parse_options.sh || exit 1;

if [ $# != 1 ]; then
   echo "Usage: $0 [options] <train language code>" 
   echo "e.g.: $0 \'SW\" "
   echo ""
fi

# Set the language codes for SBS languages that we will be processing
export TRAIN_LANG=$1  #"AR CA HG MD UR" exclude DT, error in dt_to_ipa.py

export SRC_LANGUAGES="TI"

if [[ $pow != "p" && $pow != "w" ]]; then
  echo "POW can be either p(phone) or w(word). But POW is $pow" && exit 1;
fi  

#### LANGUAGE SPECIFIC SCRIPTS HERE ####

if [ $stage -le 0 ]; then
## Data prep for monolingual data

# Data prep: monolingual in data/$L/{train,dev,eval,wav}
local/lorelei_data_prep.sh --config-dir=$PWD/conf --corpus-dir=$CORPUS \
  --languages="$TRAIN_LANG"  --trans-dir=$TRANSCRIPTS --lex-dir=$LEXICON --list-dir=$DATA_LISTS --pow=$pow
  
if [[ ! -z $unsup ]]; then
# Data prep: monolingual in data/$L/$unsup
local/lorelei_unsup_data_prep.sh --config-dir=$PWD/conf  --corpus-dir=$CORPUS \
  --unsup-name="$unsup"  --languages="$TRAIN_LANG" --list-dir=$DATA_LISTS  $SRC_LANGUAGES
fi

# Dictionaries: monolingual, in data/$L/local/dict ; multilingual in data/local/dict
echo "dict prep: $pow"
local/lorelei_dict_prep.sh --pow=$pow $SRC_LANGUAGES

# Lexicon prep: monolingual, in data/$L/lang/{L.fst,L_disambig.fst,phones.txt,words.txt}
for L in $SRC_LANGUAGES; do
  echo "lang prep: $L"
  if [[ $pow == "p" ]]; then
    utils/prepare_lang.sh --position-dependent-phones false \
      data/$L/local/dict "<unk>" data/$L/local/lang_tmp data/$L/lang
  else
    utils/prepare_lang.sh data/$L/local/dict '<unk>' data/$L/local/lang_tmp data/$L/lang
  fi
done

# LM training (based on training text): monolingual, in data/$L/lang_test/G.fst
for L in $SRC_LANGUAGES; do
  echo "LM prep: $L"
  local/sbs_format_phnlm.sh $L
done

# Lexicon + LM (based on wiki text): monolingual, in
# data/$L/lang_test_text_G/{L.fst, L_disambig.gst,G.fst}
#for L in $SRC_LANGUAGES; do
#  echo "Prep text G for $L"
#  local/lorelei_format_text_G.sh --text-phone-lm $TEXT_PHONE_LM $L
#done

fi

if [ $stage -le 1 ]; then
echo "MFCC prep"
# Make MFCC features.
for L in $SRC_LANGUAGES; do
  mfccdir=mfcc/$L  
  for x in train eval ; do    
    ( 
      steps/make_mfcc.sh --nj 4 --cmd "$train_cmd" data/$L/$x exp/make_mfcc/$L/$x $mfccdir
      steps/compute_cmvn_stats.sh data/$L/$x exp/make_mfcc/$L/$x $mfccdir
      
    ) &
  done
  wait
  echo $unsup
  for x in $unsup ; do
    (
      if [[ ! -z $unsup ]]; then
        steps/make_mfcc.sh --nj 32 --cmd "$train_cmd" data/$L/$x exp/make_mfcc/$L/$x $mfccdir
        steps/compute_cmvn_stats.sh data/$L/$x exp/make_mfcc/$L/$x $mfccdir
      fi
    ) &
  done
  wait
done

fi

exp=exp/monolingual
if [ $stage -le 2 ]; then
for L in $TRAIN_LANG; do

  if ! $decode_only ; then  
  # ==== to do  =====
  # njt = min(# speakers in train, 8)
  njt=7

  # Train monophone models
  mkdir -p $exp/mono/$L;
  steps/train_mono.sh --nj $njt --cmd "$train_cmd" \
    data/$L/train data/$L/lang $exp/mono/$L
  
  graph_dir=$exp/mono/$L/graph${graph_affix}
  mkdir -p $graph_dir
  utils/mkgraph.sh --mono data/$L/lang_test${graph_affix} $exp/mono/$L $graph_dir
  
  #steps/decode.sh --nj 4 --cmd "$decode_cmd" $graph_dir data/$L/dev \
  #  $exp/mono/$L/decode_dev${graph_affix} &    
  steps/decode.sh --nj 4 --cmd "$decode_cmd" $graph_dir data/$L/eval \
    $exp/mono/$L/decode_eval${graph_affix} &
      
  mkdir -p $exp/mono_ali/$L
  steps/align_si.sh --nj $njt --cmd "$train_cmd" \
    data/$L/train data/$L/lang $exp/mono/$L $exp/mono_ali/$L
  
  # Train triphone models with MFCC+deltas+double-deltas
  mkdir -p $exp/tri1/$L
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" $NUMLEAVES $NUMGAUSSIANS \
    data/$L/train data/$L/lang $exp/mono_ali/$L $exp/tri1/$L
  
  graph_dir=$exp/tri1/$L/graph${graph_affix}
  mkdir -p $graph_dir
  
  utils/mkgraph.sh data/$L/lang_test${graph_affix} $exp/tri1/$L $graph_dir

  #steps/decode.sh --nj 4 --cmd "$decode_cmd" $graph_dir data/$L/dev \
  #  $exp/tri1/$L/decode_dev${graph_affix} &    
  steps/decode.sh --nj 4 --cmd "$decode_cmd" $graph_dir data/$L/eval \
    $exp/tri1/$L/decode_eval${graph_affix} &  

  mkdir -p $exp/tri1_ali/$L
  steps/align_si.sh --nj $njt --cmd "$train_cmd" \
    data/$L/train data/$L/lang $exp/tri1/$L $exp/tri1_ali/$L

  # Train with LDA+MLLT transforms
  mkdir -p $exp/tri2b/$L
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" $NUMLEAVES $NUMGAUSSIANS \
    data/$L/train data/$L/lang $exp/tri1_ali/$L $exp/tri2b/$L  
  
  graph_dir=$exp/tri2b/$L/graph${graph_affix}
  mkdir -p $graph_dir
        
  utils/mkgraph.sh data/$L/lang_test${graph_affix} $exp/tri2b/$L $graph_dir
  
  #steps/decode.sh --nj 4 --cmd "$decode_cmd" $graph_dir data/$L/dev \
  #  $exp/tri2b/$L/decode_dev${graph_affix} &
  steps/decode.sh --nj 4 --cmd "$decode_cmd" $graph_dir data/$L/eval \
    $exp/tri2b/$L/decode_eval${graph_affix} &  

  mkdir -p $exp/tri2b_ali/$L
  
  steps/align_si.sh --nj $njt --cmd "$train_cmd" --use-graphs true \
    data/$L/train data/$L/lang $exp/tri2b/$L $exp/tri2b_ali/$L
  
  # Train SAT models
  steps/train_sat.sh --cmd "$train_cmd" $NUMLEAVES $NUMGAUSSIANS \
    data/$L/train data/$L/lang $exp/tri2b_ali/$L $exp/tri3b/$L
  
  graph_dir=$exp/tri3b/$L/graph${graph_affix}
  mkdir -p $graph_dir
  utils/mkgraph.sh data/$L/lang_test $exp/tri3b/$L $graph_dir
  
  #steps/decode_fmllr.sh --nj 4 --cmd "$decode_cmd" $graph_dir data/$L/dev \
  #  $exp/tri3b/$L/decode_dev${graph_affix} &
  steps/decode_fmllr.sh --nj 4 --cmd "$decode_cmd" $graph_dir data/$L/eval \
    $exp/tri3b/$L/decode_eval${graph_affix} &
  fi
  
  graph_dir=$exp/tri3b/$L/graph${graph_affix}  
  if [[ ! -z $unsup ]]; then
     nju=`nproc`
     data=data/$L/$unsup 
     sdata=$data/split$nju
     
     touch $data/text # dummy text so that local/score.sh is able to generate ASR hypotheses
     
     [[ -d $sdata && $data/feats.scp -ot $sdata ]] || utils/split_data.sh $data $nju || exit 1;
  	 steps/decode_fmllr.sh --nj $nju --skip-scoring "true" --cmd "$decode_cmd" $graph_dir $data \
  	  $exp/tri3b/$L/decode_$unsup${graph_affix} &
  	 wait
  	 local/score.sh $scoring_opts --cmd "$decode_cmd" $data $graph_dir $exp/tri3b/$L/decode_$unsup${graph_affix}
  fi
     
done
wait

fi
# Getting PER numbers
# for x in exp/*/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
