#!/usr/bin/env Rscript

# Usage: Rscript --vanilla 01-get-data-from-vk.R [Path to text file with VK token] [Path of the output file] [List of group IDs]
# e.g.: Rscript --vanilla 01-get-data-from-vk.R config/vk-token group.data.muslumovo -61751570 -72422310

# NOTE: better run it in tmux, because it can take significant time to run

#--------------------------
require(httr)
require(dplyr)
require(progress)
#--------------------------

writePostsToTsv <- function(data, output.file.name) {
  text <- c()
  for (i in 1:length(data$wall.posts)) {
    text[i] <- paste(data$wall.posts[[i]]$text, paste(data$comments[[i]], collapse = " "))
  }
  
  data.frame(author.id = sapply(data$wall.posts, function(y) y$author.id),
             post.id = sapply(data$wall.posts, function(y) y$id),
             date = sapply(data$wall.posts, function(y) y$date),
             text = text) %>%
    data.table::fwrite(file = output.file.name, append = TRUE, col.names = FALSE, sep = "\t", quote = TRUE)
}

#--------------------------
#Depth setting:
date <- 1262293200

#-------------Arguments processing-------------
args <- commandArgs(trailingOnly=TRUE)
token <- readLines(args[1])[1]
ids <- args[3:length(args)]
output.file.name <- args[2]

#-------------Data fetching-------------

#Setup empty table with headers for the output file
write.table(data.frame(author.id = "author.id", post.id = "post.id", date = "date", text = "text"),
            output.file.name,
            row.names = FALSE,
            col.names = FALSE,
            sep = "\t")
group.data <- list()

# Download data

for (i in 1:length(ids)) {
  Sys.sleep(1)
  message(Sys.time())
  message(paste0("Group number ", i, " is being processed"))
  
  group.data[[i]] <- list(wall.posts = list(), comments = list())
  
  count <- content(GET(paste0("https://api.vk.com/method/", "wall.get", 
                              "?access_token=", as.character(token), 
                              "&owner_id=", as.character(ids[i]),
                              "&filter=", "owner",
                              "&count=", "1")), as = "parsed")$response[[1]]
  
  pb <- progress_bar$new(
    format = ":spin Getting data [:bar] :percent Elapsed time: :elapsedfull ETA: :eta",
    total = (count %/% 100) + 1,
    force = TRUE)
  
  pb$tick(0)
  
  for (j in 1:((count %/% 100) + 1)) {
    Sys.sleep(0.5)
    
    current.data <- list()
    current.data <- content(GET(paste0("https://api.vk.com/method/", "wall.get", #get a batch and store it in according slots
                                       "?access_token=", as.character(token), 
                                       "&owner_id=", as.character(ids[i]),
                                       "&filter=", "owner",
                                       "&offset=", ((j - 1) * 100),
                                       "&count=", "100")), as = "parsed")$response[-1]
    
    data.dates <- sapply(current.data, function(x) x$date)
    current.data <- lapply(current.data, function(x) return(list(id = x$id, text = x$text, date = x$date, author.id = x$from_id)))
    
    comments <- list()
    comments <- lapply(current.data, function(x) {
      Sys.sleep(0.3)
      content(GET(paste0("https://api.vk.com/method/", "wall.getComments", #get a batch and store it in according slots
                         "?access_token=", as.character(token), 
                         "&owner_id=", as.character(ids[i]),
                         "&post_id=", as.character(x$id),
                         "&need_likes=", "0",
                         "&count=", "100")), as = "parsed")$response[-1] %>% lapply(function(x) x$text)
    })
    
    if (any(data.dates < date) || j == ((count %/% 100) + 1)) {
      current.data <- current.data[!(data.dates < date)] #subset to only those after the date
      
      if (length(current.data) > 0) {
        group.data[[i]]$wall.posts[((j - 1)*100 + 1):((j - 1)*100 + length(current.data))] <- current.data
        group.data[[i]]$comments[((j - 1)*100 + 1):((j - 1)*100 + length(current.data))] <- comments
      }
      
      writePostsToTsv(list(wall.posts = group.data[[i]]$wall.posts[((j - 1)*100 + 1):length(group.data[[i]]$wall.posts)], comments = group.data[[i]]$comments[((j - 1)*100 + 1):length(group.data[[i]]$wall.posts)]), output.file.name)
      pb$tick()
      break
      
    } else {
      group.data[[i]]$wall.posts[((j - 1)*100 + 1):((j - 1)*100 + length(current.data))] <- current.data
      group.data[[i]]$comments[((j - 1)*100 + 1):((j - 1)*100 + length(current.data))] <- comments
      pb$tick()
      writePostsToTsv(list(wall.posts = group.data[[i]]$wall.posts[((j - 1)*100 + 1):length(group.data[[i]]$wall.posts)], comments = group.data[[i]]$comments[((j - 1)*100 + 1):length(group.data[[i]]$wall.posts)]), output.file.name)
    }
    
  }

  message(paste0("\n", length(group.data[[i]]$wall.posts), " posts and ", sum(sapply(group.data[[i]]$comments, length)), " comments were downloaded\n"))
  message(paste0("Overall, ", sum(sapply(group.data, function(x) sapply(x, length))), " items were downloaded\n"))
}
