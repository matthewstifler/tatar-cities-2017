#!/usr/bin/env Rscript

# Usage: Rscript --vanilla 03-1-lda-speedreader.R %name of the text input file% %report files prefix% %stoplist file path% %numbers of topics to try out%
# e.g.: Rscript --vanilla 03-lda-speedreader.R data/data-elabuga.csv elabuga-lda data/stoplist 5 10 50

#------------------

require(SpeedReader)
# require(ggplot2)
# require(tidyquant)
require(dplyr)

#------------------

args <- commandArgs(trailingOnly=TRUE)

data <- read.delim(args[1], stringsAsFactors = FALSE)

report.prefix <- args[2]

stoplist.file <- args[3]

n.of.topics <- as.numeric(args[4:length(args)])

#------------------

dir.create(file.path("lda-reports"), showWarnings = FALSE)

for (i in n.of.topics) {
  lda.result <- mallet_lda(documents = as.character(data$text),
                                        topics = i,
                                        iterations = 1500,
                                        hyperparameter_optimization_interval = 10,
                                        tokenization_regex = "[\\p{L}\\p{N}-]*\\p{L}+",
                                        cores = 8,
                                        stopword_list = readLines(stoplist.file),
                                        delete_intermediate_files = TRUE)
  
  #----------Writing results----------
  dir.create(file.path("lda-reports", paste0(report.prefix, "-", i)), showWarnings = FALSE)
  
  write.csv(lda.result$document_topic_proportions,
            paste0("lda-reports/", report.prefix, "-", i, "/", report.prefix, "-", i, "-doc-topics.csv"),
            row.names = FALSE)
  
  data.frame(topic = 1:i,
             size = lda.result$topic_metadata$total_tokens,
             label = apply(lda.result$topic_top_words, 1, function(x) paste(x, collapse = ", "))) %>% 
    write.csv2(paste0("lda-reports/", report.prefix, "-", i, "/", report.prefix, "-", i, "-topic-labels.csv"),
               row.names = FALSE)
  
  data.frame(topic = 1:i,
             size = lda.result$topic_metadata$total_tokens,
             label = apply(lda.result$topic_top_phrases, 1, function(x) paste(x, collapse = ", "))) %>% 
    write.csv2(paste0("lda-reports/", report.prefix, "-", i, "/", report.prefix, "-", i, "-topic-phrases.csv"),
               row.names = FALSE)
}
