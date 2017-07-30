#!/usr/bin/env Rscript

# Usage: Rscript --vanilla 03-lda.R %name of the text input file% %name of the report output file% %stoplist file path% %numbers of topics to try out%
# e.g.: Rscript --vanilla 03-lda.R data/data-elabuga.csv elabuga-lda-report.csv 5 10 50

#------------------

require(mallet)
# require(ggplot2)
# require(tidyquant)
require(dplyr)

#------------------

runLDA <- function(data, n.of.topics, stoplist.file, report.file.name) {
  for (i in n.of.topics) {
    mallet.instances <- mallet.import(as.character(1:length(data$text)), as.character(data$text), stoplist.file, token.regexp = "[\\p{L}\\p{N}-]*\\p{L}+") #as.character so that there is no error (important!)
    
    topic.model <- MalletLDA(num.topics = as.numeric(i)) # количество тем
    topic.model$loadDocuments(mallet.instances) 
    topic.model$setAlphaOptimization(20, 50)
    topic.model$train(1500)
    topic.model$maximize(25)
    
    topic.labels <- list()
    
    topic.words <- mallet.topic.words(topic.model, smoothed=TRUE, normalized=TRUE)
    doc.topics <- mallet.doc.topics(topic.model, smoothed=TRUE, normalized=TRUE)
    
    for (k in 1:nrow(topic.words)) {
      topic.labels[[k]] <- mallet.top.words(topic.model, topic.words[k,], 20)$words
    }
    
    doc.length <- strsplit(as.character(data$text), " ") %>% sapply(length)
    size <- apply(doc.topics, 2, function(x) {
      return(sum(x * doc.length))
    }) %>% round
    
    if (length(n.of.topics) > 1) {
      dir.create(file.path("lda-reports"), showWarnings = FALSE)
      
      write.csv(cbind(topic.id = 1:i,
                      topic.label = gsub("c", "", topic.labels) %>% gsub("[[:punct:]]", "", .),
                      size = size
      ),
      paste0("lda-reports/", report.file.name, "-", i, ".csv"),
      row.names = FALSE
      )
    } else {
      write.csv(cbind(topic.id = 1:i,
                      topic.label = gsub("c", "", topic.labels) %>% gsub("[[:punct:]]", "", .),
                      size = size
      ),
      paste0(report.file.name, ".csv"),
      row.names = FALSE
      )
    }
    
  }
}

#------------------

args <- commandArgs(trailingOnly=TRUE)

data <- read.csv(args[1], stringsAsFactors = FALSE)

if (stringr::str_detect(args[2], "\\.csv")) {
  report.file.name <- unlist(strsplit(args[2], ".csv"))
} else {
  report.file.name <- args[2]
}

stoplist.file <- args[3]

n.of.topics <- as.numeric(args[4:length(args)])

#------------------

runLDA(data, n.of.topics, stoplist.file, report.file.name)

#hierarchical
# plot(mallet.topic.hclust(doc.topics, topic.words, 0.5)) 


# All of the code below makes no sense, because topics, apparently, cannot be clustered or meaningfully be projected
# on 2 dimensions, due to the lack of correlations between them

#regular clustering + t-sne
# topics.dist <- cluster::daisy(doc.topics, metric = "gower") #t(), bc topics are clustered
# 
# topics.tsne <- Rtsne::Rtsne(topics.dist, is_distance = TRUE, perplexity = 10, verbose = T, max_iter = 10000)$Y %>% 
#   as.data.frame() %>% 
#   setNames(c("X", "Y")) #%>% 
#   # mutate(name = 1:30, 
#          # size = round(colSums(doc.topics) / 100))
# 
# ggplot(aes(x = X, y = Y, label = name), data = topics.tsne) +
#   geom_point(aes(size = size)) +
#   geom_text(nudge_x = 0.1, size = 5) + 
#   theme_tq() +
#   theme(axis.title = element_blank(),
#         axis.text = element_blank(),
#         plot.margin = margin(10, 5, 10, 10),
#         text = element_text(size = 16))
