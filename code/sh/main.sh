#!/bin/bash

# 1. Run processing
# 2. Run LDA
# 3. Get top texts (in the future)

# Usage: bash ./code/sh/main.sh [Raw data source: text in "text column"] [Path to save file with clean text] [Stoplist path] [LDA report prefix] [Number of cores to use for LDA] [Numbers of topics]
# Example: bash ./code/sh/main.sh

#----------Handling arguments-----------

dataSource=$1
cleanedFilePath=$2
stoplistPath=$3
reportPrefix=$4
nOfCores=$5

#----------Handling arbitrary number of topics----------
topicsArray=()

for ((i=6; i<=$#; i++))
  do
    topicsArray+=(${!i}) #adding i-th argument to the array
  done

#----------Doing the deeds----------

Rscript --vanilla code/R/02-processing-text-data.R $dataSource $cleanedFilePath $stoplistPath &

wait $!

Rscript --vanilla code/R/03-1-lda-speedreader.R $cleanedFilePath $reportPrefix $stoplistPath $nOfCores printf '%s\n' "${topicsArray[*]}" # Some bash hack to print array
