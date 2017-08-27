#!/bin/bash

# 1. Run processing
# 2. Run LDA
# 3. Get top texts (in the future)

# Usage: bash ./code/sh/main.sh [Raw data source: text in "text column"] [Path to save file with clean text] [Stoplist path] [LDA report prefix] [Number of cores to use for LDA] [Numbers of topics]
# Example: bash ./code/sh/main.sh data/data-muslumovo.tsv data/data-muslumovo-processed.tsv data/stoplist-tatar muslumovo 6 10 20 30 40 50 60

#----------Handling arguments-----------

dataSource=$1
cleanedFilePath=$2
stoplistPath=$3
reportPrefix=$4
nOfCores=$5

pathToDocTopics="lda-reports/$reportPrefix"

#----------Handling arbitrary number of topics----------
topicsArray=()

for ((i=6; i<=$#; i++))
  do
    topicsArray+=(${!i}) #adding i-th argument to the array
  done

#----------Doing the deeds----------

Rscript --vanilla code/R/02-processing-text-data.R $dataSource $cleanedFilePath $stoplistPath
Rscript --vanilla code/R/03-1-lda-speedreader.R $cleanedFilePath $reportPrefix $stoplistPath $nOfCores "${topicsArray[@]}" # Some bash hack to print array
python code/py/get_top_texts.py $pathToDocTopics $dataSource $reportPrefix

#----------Zipping all together and publishing----------
pathForReport="../public_html/$reportPrefix.zip" 
zip -r9 $pathForReport $dataSource $pathToDocTopics "top-texts/$reportPrefix"
