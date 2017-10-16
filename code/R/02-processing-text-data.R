#!/usr/bin/env Rscript

# Usage: Rscript --vanilla 02-processing-text-data.R %input file% %output file% %stoplist file path%
# e.g.: Rscript --vanilla 02-processing-text-data.R data/data-elabuga.csv data/data-elabuga-processed.csv data/stoplist

#-------------------

require(dplyr)

#-------------------

lemmatize <- function(text.data) {
  tempfile.path <- tempfile("text-vec")
  writeLines(text.data, file.path(tempfile.path))
  
  output <- system(paste0("mystem -cld ", tempfile.path, " | cat"), intern = T) %>% 
    gsub("[[:punct:]]", " ", .) %>% 
    gsub("\\s{2,}", " ", .) %>% 
    trimws()
  
  file.remove(tempfile.path)
  return(output)
}

#----------Arguments processing-----------

args <- commandArgs(trailingOnly=TRUE)

data <- data.table::fread(args[1], quote = "")

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

message("All words are in their initial form")
message(Sys.time())

stopwords <- readLines(stoplist.file.name)
stopwords_regex <- paste(stopwords, collapse = '\\b|\\b')
stopwords_regex <- paste0('\\b', stopwords_regex, '\\b')
data$text <- stringr::str_replace_all(data$text, stopwords_regex, " ") %>% gsub("\\s{2,}", " ", .)

message("Stopwords removed") 
message(Sys.time())

data.table::fwrite(data, output.file.name, sep = "\t")
message("Output file is written, the script is finished")
