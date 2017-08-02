#!/usr/bin/env Rscript

# Usage: Rscript --vanilla get-top-texts-for-topic.R %path to doc-topic file% %path to posts% %topic number% %number of posts to fetch%
# e.g.: Rscript --vanilla get-top-texts-for-topic.R lda-reports/elabuga-lda-100/elabuga-lda-100-doc-topics.csv data/data-elabuga.csv 72 20

#-------------------

args <- commandArgs(trailingOnly=TRUE)

doc.topic.path <- args[1]
data.path <- args[2] # Must be the same data as was used for LDA modelling
topic <- as.numeric(args[3])
n.of.posts <- as.numeric(args[4])

#-------------------

data <- read.csv(data.path, stringsAsFactors = FALSE)
doc.topics <- read.csv(doc.topic.path, stringsAsFactors = FALSE)

doc.indices <- order(doc.topics[, topic], decreasing = TRUE)[1:n.of.posts]

print(data$text[doc.indices])