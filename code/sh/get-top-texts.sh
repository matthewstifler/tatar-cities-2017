#!/bin/bash

# Usage: bash 100 50 lda-reports/elabuga-lda-100/elabuga-lda-100-doc-topic.csv data/data-elabuga-processed.csv
# Run from project root

# TODO: Automatically identify number of topics (N of columns in doc-topic matrix, i.e. number of commas + 1)
#       Automatically name folder (i.e. name of the doc-topic matrix), so that there aren't same folders (perhaps, add numbers to the name: folder-1, folder-2)
#       Replace R script with python or bash, to speed things up

nOfTopics=$1
nOfPosts=$2
docTopic=$3
textSource=$4

mkdir top-texts-lda && cd $_

for ((i=1; i<=$nOfTopics; i++))
  do
    Rscript --vanilla ../code/R/get-top-texts-for-a-topic.R ../$docTopic ../$textSource $i $nOfPosts > "topic-$i.txt"
 done
 