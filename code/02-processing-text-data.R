#!/usr/bin/env Rscript

# Usage: Rscript --vanilla 02-processing-text-data.R %input file% %output file% %stoplist file path%
# e.g.: Rscript --vanilla 02-processing-text-data.R data/data-elabuga.csv data/data-elabuga-processed.csv data/stoplist

#-------------------

require(dplyr)

#-------------------

lemmatize <- function(text.data) {
  writeLines(text.data, "text-vec")
  output <- system("mystem -cld text-vec | cat", intern = T) %>% 
    gsub("[[:punct:]]", " ", .) %>% 
    gsub("\\s{2,}", " ", .) %>% 
    trimws()
  
  file.remove("text-vec")
  return(output)
}

#----------Arguments processing-----------

args <- commandArgs(trailingOnly=TRUE)

data <- read.csv(file = args[1], stringsAsFactors = FALSE)

output.file.name <- args[2]

if (length(args) > 2) {
  stoplist.file.name <- args[3]
}

#---------Processing text----------

data$text <- gsub("(https://)(\\S*)", " ", data$text) %>%
    gsub("ё", "е", .) %>%
    gsub("Ё", "Е", .) %>%
    gsub("[[:digit:]]", "", .) %>% 
    gsub("[[:punct:]]", " ", .) %>% 
    gsub("[A-Za-z]", "", .) %>%
    gsub("[\U{1F300}-\U{1F6FF}]", "", .) %>% #why emojis don't get caught?
    stringr::str_to_lower() %>% 
    trimws %>% 
    gsub("\\s{2,}", " ", .)

message("Text cleaned")
message(Sys.time())

data$text <- lemmatize(data$text)

message("All words are in their dictionary form")
message(Sys.time())

stopwords <- readLines(stoplist.file.name)
data$text <- tm::removeWords(data$text, stopwords) %>% gsub("\\s{2,}", " ", .)
message("Stopwords removed!") 
message(Sys.time())

write.csv(data, output.file.name, row.names = FALSE)
message("Output file is written, the script is finished")