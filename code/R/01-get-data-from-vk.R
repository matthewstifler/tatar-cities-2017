#!/usr/bin/env Rscript

# Usage: Rscript --vanilla 01-get-data-from-vk.R %name of output file% %list of group IDs%
# e.g.: Rscript --vanilla 01-get-data-from-vk.R group.data.muslumovo -61751570 -72422310

# NOTE: better run it in tmux, because it can take significant time to run

#--------------------------
require(httr)
require(dplyr)
require(progress)
#--------------------------

writePostsToCsv <- function(data, output.file.name) {
  text <- c()
  for (i in 1:length(data$wall.posts)) {
    text[i] <- paste(data$wall.posts[[i]]$text, paste(data$comments[[i]], collapse = " "))
  }
  
  data.frame(author.id = sapply(data$wall.posts, function(y) y$author.id),
             post.id = sapply(data$wall.posts, function(y) y$id),
             date = sapply(data$wall.posts, function(y) y$date),
             text = text) %>%
    write.table(file = output.file.name, append = TRUE, row.names = FALSE, col.names = FALSE, sep = ",")
}

#--------------------------
#Depth setting:
date <- 1262293200
args <- commandArgs(trailingOnly=TRUE)
ids <- args[2:length(args)]
output.file.name <- args[1]

#Setup empty table with headers for the output file
write.table(data.frame(author.id = "author.id", post.id = "post.id", date = "date", text = "text"),
            output.file.name,
            row.names = FALSE,
            col.names = TRUE,
            sep = ",")
group.data <- list()

# Download data

for (i in 1:length(ids)) {
  Sys.sleep(1)
  message(Sys.time())
  message(paste0("Group number ", i, " is being processed"))
  
  group.data[[i]] <- list(wall.posts = list(), comments = list())
  
  count <- content(GET(paste0("https://api.vk.com/method/", "wall.get", 
                              "?access_token=", "24f3f52000d221fb9d47c9039134fb3623108c4cf67d24dae0b772702d1b9ab6750c220e3ff7989cd3a17", 
                              "&owner_id=", as.character(ids[i]),
                              "&filter=", "owner",
                              "&count=", "1")), as = "parsed")$response[[1]]
  
  pb <- progress_bar$new(
    format = ":spin Getting data [:bar] :percent Elapsed time: :elapsedfull ETA: :eta",
    total = (count %/% 100) + 1)
  
  pb$tick(0)
  
  for (j in 1:((count %/% 100) + 1)) {
    Sys.sleep(0.5)
    
    current.data <- list()
    current.data <- content(GET(paste0("https://api.vk.com/method/", "wall.get", #get a batch and store it in according slots
                                       "?access_token=", "24f3f52000d221fb9d47c9039134fb3623108c4cf67d24dae0b772702d1b9ab6750c220e3ff7989cd3a17", 
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
                         "?access_token=", "24f3f52000d221fb9d47c9039134fb3623108c4cf67d24dae0b772702d1b9ab6750c220e3ff7989cd3a17", 
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
      
      break
      
    } else {
      group.data[[i]]$wall.posts[((j - 1)*100 + 1):((j - 1)*100 + length(current.data))] <- current.data
      group.data[[i]]$comments[((j - 1)*100 + 1):((j - 1)*100 + length(current.data))] <- comments
    }
    
    writePostsToCsv(list(wall.posts = group.data[[i]]$wall.posts[((j - 1)*100 + 1):length(group.data[[i]]$wall.posts)], comments = group.data[[i]]$comments[((j - 1)*100 + 1):length(group.data[[i]]$wall.posts)]), output.file.name)
    pb$tick()
  }
  
  message(paste0("\n", length(group.data[[i]]$wall.posts), " posts and ", length(group.data[[i]]$comments), " comments were downloaded\n"))
  message(paste0("Overall, ", sum(sapply(group.data, function(x) sapply(x, length))), " items were downloaded\n"))
}

# lapply(group.data, function(x) {
#   text <- c()
#   for (i in 1:length(x$wall.posts)) {
#     text[i] <- paste(x$wall.posts[[i]]$text, paste(x$comments[[i]], collapse = " "))
#   }
#   return(data.frame(author.id = sapply(x$wall.posts, function(y) y$from_id),
#                     post.id = sapply(x$wall.posts, function(y) y$id),
#                     date = sapply(x$wall.posts, function(y) y$date),
#                     text = text))
# }) %>% {do.call(rbind, .)} %>% 
#   write.csv(file = output.file.name,
#             row.names = FALSE)
# 
