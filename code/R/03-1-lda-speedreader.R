#!/usr/bin/env Rscript

# Usage: Rscript --vanilla 03-1-lda-speedreader.R %name of the text input file% %report files prefix% %stoplist file path% %number of cores to use% %numbers of topics to try out%
# e.g.: Rscript --vanilla 03-lda-speedreader.R data/data-elabuga.csv elabuga-lda data/stoplist 5 10 50

#------------------

require(SpeedReader)
# require(ggplot2)
# require(tidyquant)
require(dplyr)

#------------------

args <- commandArgs(trailingOnly=TRUE)

data <- read.delim(args[1], stringsAsFactors = FALSE, quote = "")
report.prefix <- args[2]
stoplist.file <- args[3]
n.of.cores <- args[4]
n.of.topics <- as.numeric(args[5:length(args)])

#------------------

dir.create(file.path("lda-reports"), showWarnings = FALSE)
dir.create(file.path("lda-reports", report.prefix), showWarnings = FALSE)

home.path <- getwd()

for (i in n.of.topics) {
  
  #---------Create folder structure---------
  
  current.path <- file.path("lda-reports", report.prefix, paste0(i, "-topics"))
  dir.create(current.path, showWarnings = FALSE)
  
  #---------Run actual LDA---------
  
  #Running it from tempdir, so that intermediate files don't get mixed up
  setwd(tempdir())
  
  lda.result <- mallet_lda(documents = as.character(data$text),
                                        topics = i,
                                        iterations = 1500,
                                        hyperparameter_optimization_interval = 10,
                                        tokenization_regex = "[\\p{L}\\p{N}-]*\\p{L}+",
                                        cores = n.of.cores,
                                        stopword_list = readLines(stoplist.file),
                                        delete_intermediate_files = TRUE)
  
  setwd(home.path)
  #----------Writing results----------
  write.csv(lda.result$document_topic_proportions,
            file.path(current.path, paste0(report.prefix, "-", i, "-doc-topics.csv")),
            row.names = FALSE)
  
  data.frame(topic = 1:i,
             size = lda.result$topic_metadata$total_tokens,
             label = apply(lda.result$topic_top_words, 1, function(x) paste(x, collapse = ", "))) %>% 
    write.csv2(file.path(current.path, paste0(report.prefix, "-", i, "-topic-labels.csv")),
               row.names = FALSE)
  
  data.frame(topic = 1:i,
             size = lda.result$topic_metadata$total_tokens,
             label = apply(lda.result$topic_top_phrases, 1, function(x) paste(x, collapse = ", "))) %>% 
    write.csv2(file.path(current.path, paste0(report.prefix, "-", i, "-topic-phrases.csv")),
               row.names = FALSE)
}
