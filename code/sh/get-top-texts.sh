#!/bin/bash

# Usage: bash 100 50 lda-reports/elabuga-lda-100/elabuga-lda-100-doc-topic.csv data/data-elabuga-processed.csv
# Run from project root

nOfTopics=$1
nOfPosts=$2
docTopic=$3
textSource=$4

mkdir top-texts-lda && cd $_

for ((i=1; i<=$nOfTopics; i++))
  do
    Rscript --vanilla ../code/R/get-top-texts-for-a-topic.R ../$docTopic ../$textSource $i $nOfPosts > "topic-$i.txt"
 done
 
