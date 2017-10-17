#!/usr/bin/env Rscript

# Usage: Rscript --vanilla code/R/04-reports-rendering.R [Path to text file with VK token] [Report prefix] [Path to the folder with report files: "author.id" -- group.id, "post.id"]
# e.g.: Rscript --vanilla  code/R/04-reports-rendering.R code/config/vk-token muslumovo top-texts/muslumovo

# ISSUE: Some file.paths are skipped for unknown reasons?!

require(progress)

#--------------------------

source("code/R/report-funs.R")

#------------------Arguments processing-------------------

args <- commandArgs(trailingOnly=TRUE)
token <- readLines(args[1])[1]
prefix <- args[2]
reports.folder <- ifelse(stringr::str_detect(args[3], "/$"),
                         gsub("/$", "", args[3]),
                         args[3]) # Trailing slash leads to creating wrong paths 

#-----------------Getting work done-------------------

# Construct paths to all files
folders <- list.files(reports.folder)

files.paths <- sapply(folders, function(folder) {
  files <- list.files(paste(reports.folder, folder, sep = "/"))
  paste(reports.folder, folder, files,  sep = "/")
}) %>% unlist

dir.create("topic-reports")
dir.create(paste0("topic-reports/", prefix))

pb <- progress_bar$new(
  format = ":spin Rendering :report [:bar] :percent Elapsed time: :elapsedfull ETA: :eta",
  total = length(files.paths) + 1,
  force = TRUE,
  stream = stdout()
  )

# Get data for each post
for (path in files.paths) {
  # message(path)
  attempt.number <- 1
  
  folder <- strsplit(path, "/")[[1]][3]
  file.path <- paste0("topic-reports/", prefix, "/", folder, "/", strsplit(strsplit(path, "/")[[1]][4], "\\.")[[1]][1], ".html")
  
  pb$tick(tokens = list(report = file.path))
  
  suppressWarnings(dir.create(paste0("topic-reports/", prefix, "/", folder)))
  
  topic.report <- read.delim(path, header = FALSE, col.names = c('author.id', 'post.id', 'date', 'link', 'topic.label', 'topic.weight', 'text'))
  
  # This is a workaround for occaional pandoc fails
  while(!file.exists(file.path) && attempt.number <= 4) {
    attempt.number <- attempt.number + 1
    try({
      posts.list <- topic.report[, 1:2] %>%
        fetchPostsById(token) %>% 
        fetchCommentsById(token)
      renderReport(posts.list, token, topic.report$topic.weight, topic.report$topic.label[1], prefix, folder, strsplit(strsplit(path, "/")[[1]][4], "\\.")[[1]][1])},
      silent = TRUE
    )
  }

}
