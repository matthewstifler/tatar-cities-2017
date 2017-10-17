require(httr)
require(dplyr)
require(progress)

#-------------------Data fetching functions--------------------

fetchPostsById <- function(ids.dataframe, token) {
  ids <- paste(ids.dataframe[, 1], ids.dataframe[, 2], sep = "_")
  
  output.attchments <- list()
  
  # Get data
  Sys.sleep(0.3)
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
    Sys.sleep(0.3)
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

addNamesToComments <- function(comments.items, comments.profiles) {
  authors.ids <- unique(sapply(comments.profiles, function(profile) profile$id))
  
  return(lapply(comments.items, function(comment) {
    # message(comment$from_id)
    author.profile <- comments.profiles[authors.ids == comment$from_id][[1]]
    
    # Control for profiles vs groups
    if(!is.null(author.profile$first_name)) {
      comment$first_name <- author.profile$first_name
      comment$last_name <- author.profile$last_name
    } else {
      comment$name <- author.profile$name
    }
    
    return(comment)
  }))
}

fetchCommentsById <- function(posts.list, token) {
  lapply(posts.list, function(post) {
    # message(post$id)
    comments.count <- post$comments.count
    # message(comments.count)
    
    if(comments.count <= 100) {
      Sys.sleep(1)
      comments.raw <- content(GET(paste0("https://api.vk.com/method/", "wall.getComments", 
                                         "?access_token=", as.character(token), 
                                         "&owner_id=", as.character(post$group_id),
                                         "&post_id=", as.character(post$id),
                                         "&count=", "100",
                                         "&v=", "5.68",
                                         "&extended=", "1"
      )
      ),
      as = "parsed")$response[-1]
    } else if(comments.count > 100) {
      comments.raw <- list(items = list(), profiles = list(), groups = list())
      for (j in 1:((comments.count %/% 100) + 1)) {
        Sys.sleep(1)
        
        current.data <- list()
        current.data <- content(GET(paste0("https://api.vk.com/method/", "wall.getComments", 
                                           "?access_token=", as.character(token), 
                                           "&owner_id=", as.character(post$group_id),
                                           "&post_id=", as.character(post$id),
                                           "&offset=", ((j - 1) * 100),
                                           "&count=", "100",
                                           "&v=", "5.68",
                                           "&extended=", "1"
        )
        ),
        as = "parsed")$response[-1]
        
        comments.raw$items[((j - 1) * 100 + 1):((j - 1) * 100 + length(current.data$items))] <- current.data$items
        comments.raw$profiles[(length(comments.raw$profiles) + 1):(length(comments.raw$profiles) + length(current.data$profiles))] <- current.data$profiles
        comments.raw$groups[(length(comments.raw$groups) + 1):(length(comments.raw$groups) + length(current.data$groups))] <- current.data$groups
      }
    } else if(comments.count == 0) {
      comments.raw <- list()
    }
    
    if(length(comments.raw$items) > 0) {
      # Combining groups and profiles info
      
      if(length(comments.raw$groups) > 0) {
        
        # Accounting for stupid API returning group ids without leading dash in `groups` but with the dash in `items`
        # 🤔
        message("About to do group id!")
        comments.raw$groups <- lapply(comments.raw$groups, function(group) {
          group$id <- paste0("-", group$id)
          
          return(group)
        })
        message("Group id worked!")
        
        n.of.profiles <- length(comments.raw$profiles)
        for(i in 1:length(comments.raw$groups)) {
          comments.raw$profiles[[n.of.profiles + i]] <- comments.raw$groups[[i]]
        }
      }
      
      comments.raw$items <- addNamesToComments(comments.raw$items, comments.raw$profiles)
    }
    
    post$comments <- comments.raw$items
    
    return(post)
  })
}

#-------------------Report rendering functions--------------------

addGroupNames <- function(posts.list, token) {
  group.ids <- unique(sapply(posts.list, function(post) post$group_id))
  
  Sys.sleep(0.3)
  group.names <- content(GET(paste0("https://api.vk.com/method/", "groups.getById", 
                                    "?access_token=", as.character(token), 
                                    "&group_ids=", paste(gsub("-", "", group.ids), collapse = ","),
                                    "&v=", "5.68"
  )
  ), as = "parsed"
  )$response %>% sapply(function(group) group$name)
  
  posts.list <- lapply(posts.list, function(post) {
    post$group_name <- group.names[group.ids == post$group_id]
    return(post)
  })
  
  return(posts.list)
} 

addDataToPostsForRender <- function(posts.list, token) {
  posts.list <- addGroupNames(posts.list, token)
  
  return(posts.list)
}

attachmentToMarkdown <- function(attachment) {
  # If some attachments have no type, skip them, they are broken (hacky, ikr)
  if (is.null(attachment$type)) {
    return("")
  }
  
  if (attachment$type == "photo") {
    
    return(paste0("[![](", attachment$src_big, ")](", attachment$src_big, ")"))
    
  } else if (attachment$type == "video") {
    
    if (is.null(attachment[["vid"]])) {
      return(paste0("[![](", attachment$video$photo_320, ")](",
                    paste0("https://vk.com/video", attachment$video$owner_id, "_", attachment$video$id), # creating a link for video
                    ")\n", attachment$video$title))
    } else {
      return(paste0("[![](", attachment$image, ")](",
                    paste0("https://vk.com/video", attachment$owner_id, "_", attachment$vid), # creating a link for video
                    ")\n", attachment$title))
    }
    
  } else if (attachment$type == "sticker") {
    
    return(paste0("[![](", attachment$photo_128, ")](", attachment$photo_128, ")"))
    
  }
}

postToMarkdown <- function(post) {
  # message(post$id)
  post.header <- paste(
    paste0("###[Пост № ", post$id, "](", paste0("https://vk.com/wall", post$group_id, "_", post$id), ")"),
    paste0("**Группа**: ", post$group_name),
    paste0("**Дата**: ", as.POSIXct(post$date, origin  = "1970-01-01 00:00:00")),
    paste0("**Лайки**: ", post$likes.count),
    paste0("**Репосты**: ", post$reposts.count),
    paste0("**Комментарии**: ", post$comments.count),
    paste0("**Доля топика в тексте поста**: ", post$topic.weight),
    sep = "\n\n"
    )
  
  # message(post.header)
  
  post.body <- paste(post$text)
  
  # Processing attachments
  if(!is.null(post$attachments)) {
    attachments <- lapply(post$attachments, attachmentToMarkdown) %>%
      paste(sep = "\n\n", collapse = "\n\n")
    
    post.body <- paste(post.body, attachments, sep = "\n\n")
    
  }
  
  # Processing comments
  if (post$comments.count > 0) {
    post.comments <- lapply(post$comments, function(comment) {
      
      comment.md <- ""
      
      # Control for profiles vs groups
      if (!is.null(comment$first_name)) {
        comment.md <- paste0("*", comment$first_name, " ", comment$last_name, "*: ", comment$text)
      } else {
        comment.md <- paste0("*", comment$name, "*: ", comment$text)
      }
      
      if (!is.null(comment$attachments)) {
        attachments <- lapply(comment$attachments, attachmentToMarkdown) %>% 
          paste(sep = "", collapse = "")
        
        comment.md <- paste(comment.md, attachments, sep = " ", collapse = " ")
        
        return(comment.md)
      }
      
      return(comment.md)
      
    }) %>% paste(sep = "\n\n", collapse = "\n\n")
    
    return(paste(post.header, post.body, "####Комментарии:", post.comments, sep = "\n\n"))
  }
  
  # Returning results
  return(paste(post.header, post.body, sep = "\n\n"))
}

renderReport <- function(posts.list, token, topic.weights, topic.label, prefix, folder, file.name) {
  # Constructing needed paths
  output.dir <- paste0("topic-reports/", prefix, "/", folder)
  rmd.path <- paste0(output.dir, "/", file.name, ".Rmd")
  
  # Preparing data for the report header
  topic.number <- strsplit(file.name, "-")[[1]][1]
  n.of.topics <- strsplit(folder, "-")[[1]][1]
  
  header.md <- paste0("#Топик №", topic.number, " в модели на ", n.of.topics, " тем", "\n\n",
                     "*Слова, характеризующие топик*: ", topic.label, "\n\n")
  
  # Adding group names to the posts and topic weights
  posts.list <- posts.list %>% 
    addDataToPostsForRender(token) %>% 
    {mapply(
      function(post, topic.weight) {
        post$topic.weight <- round(topic.weight, 4)
        return(post)
      }, ., topic.weights)}
  
  # Rendering
  posts.md <- lapply(posts.list, postToMarkdown)
  paste(posts.md, collapse = "\n\n *** \n\n") %>% 
    {paste0(header.md, .)} %>% 
    writeLines(rmd.path)
  
  rmarkdown::render(input = rmd.path, output_format = rmarkdown::html_document(self_contained = FALSE), output_file = paste(file.name, "html", sep = "."), output_dir = output.dir, quiet = TRUE)
  
  file.remove(rmd.path)
}

