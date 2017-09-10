#!/usr/bin/env Rscript

# Usage: Rscript --vanilla  [Path to text file with VK token] [Path to the folder with report files: "author.id" -- group.id, "post.id"]
# e.g.: Rscript --vanilla  

#--------------------------
require(httr)
require(dplyr)
require(progress)
#-------------------Functions declaration--------------------

fetchPostsById <- function(ids.dataframe, token) {
  ids <- paste(ids.dataframe[, 1], ids.dataframe[, 2], sep = "_")
  
  output.attchments <- list()
  
  # Get data
  raw.data <- content(GET(paste0("https://api.vk.com/method/", "wall.getById", 
                     "?access_token=", as.character(token), 
                     "&posts=", as.character(paste(ids, collapse = ","))
                     )
              ), as = "parsed"
          )$response
  
  # Process attachments to leave only desired fields
  raw.attachments <- lapply(raw.data, function(post) {
    if (!is.null(post$attachments)) {
      lapply(post$attachments, function(attachment) {
        return(
          switch (attachment$type,
            photo = list(type = "photo",
                         src = attachment$photo$src,
                         src_big = attachment$photo$src_big,
                         text = attachment$photo$text
                         ),
            posted_photo = list(type = "posted_photo",
                                src = attachment$posted_photo$photo_130,
                                src_big = attachment$posted_photo$photo_604,
                                text = ""
                                ),
            video = list(type = "video",
                         owner_id = attachment$video$owner_id,
                         vid = attachment$video$vid,
                         image = attachment$video$image,
                         description = attachment$video$description,
                         title = attachment$video$title,
                         duration = attachment$video$duration
                         )
          )
        )
      }) 
    }
  })
  
  # Process posts data to leave only desired fields
  raw.data <- lapply(raw.data, function(post) {
    # If the post author is specified, get his name and store it to the variable
    author <- ifelse(is.null(post$signer_id), content(GET(paste0("https://api.vk.com/method/", "user.get", 
                                                                 "?access_token=", as.character(token), 
                                                                 "&user_ids=", as.character(post$signer_id)))
                                                      , as = "parsed")$response[[1]][c("first_name", "last_name")] %>%
                       unlist %>%
                       paste(collapse = " ")
                     , NA)
    
    return(list(id = post$id,
                group_id = post$from_id,
                date = post$date,
                text = post$text,
                comments.count = post$comments$count,
                likes.count = post$likes$count,
                reposts.count = post$reposts$count,
                author = author
                ))
  })
  
  raw.data <- mapply(function(post, post.attachments) {
    post$attachments <- post.attachments
    return(post)
  }, raw.data, raw.attachments, SIMPLIFY = FALSE)
  
  return(raw.data)
}

fetchCommentsById <- function(posts.list, token) {
  lapply(posts.list, function(post) {
    
    comments.count <- content(GET(paste0("https://api.vk.com/method/", "wall.getComments", 
                                         "?access_token=", as.character(token), 
                                         "&owner_id=", as.character(post$group_id),
                                         "&post_id=", as.character(post$id),
                                         "&count=", "1")), as = "parsed")$response[[1]]
    
    if(comments.count < 100) {
      comments.raw <- content(GET(paste0("https://api.vk.com/method/", "wall.getComments", 
                                         "?access_token=", as.character(token), 
                                         "&owner_id=", as.character(post$group_id),
                                         "&post_id=", as.character(post$id),
                                         "&count=", "100",
                                         "&v=", "5.68"
                                         )
                                  ),
                              as = "parsed")$response[-1]
    } else if(comments.count > 100) {
      for (j in 1:((comments.count %/% 100) + 1)) {
        Sys.sleep(0.3)
        
        current.data <- list()
        current.data <- content(GET(paste0("https://api.vk.com/method/", "wall.getComments", 
                                           "?access_token=", as.character(token), 
                                           "&owner_id=", as.character(post$group_id),
                                           "&post_id=", as.character(post$id),
                                           "&offset=", ((j - 1) * 100),
                                           "&count=", "100",
                                           "&v=", "5.68"
                                           )
                                    ),
                                as = "parsed")$response[-1]
        
        comments.raw[((j - 1) * 100 + 1):((j - 1) * 100 + length(current.data))] <- current.data
      }
    } else if(comments.count == 0) {
      comments.raw <- NULL
    }
    
    # TODO: Comments responses, attachments
    post$comments <- comments.raw
  })
}

#------------------Arguments processing-------------------

args <- commandArgs(trailingOnly=TRUE)
token <- readLines(args[1])[1]
reports.folder <- args[2]

#-----------------Getting work done-------------------

# Construct paths to all files
folders <- list.files(reports.folder)

files.paths <- sapply(folders, function(folder) {
  files <- list.files(paste(reports.folder, folder, sep = "/"))
  paste(reports.folder, folder, files,  sep = "/")
}) %>% unlist

# Get data for each post
for (path in files.paths) {
  read.delim(path, header = FALSE)[, 1:2] %>%
    fetchPostsById(token) %>% 
    fetchCommentsById(token)
}
