#!/usr/bin/env Rscript

# Usage: Rscript --vanilla code/R/topic-dynamic.R [Path to text file with selected topics numbers] [Report prefix] [Lda report path] [Text data path]
# e.g.: Rscript --vanilla  

#------------------Loading packages-------------------

require(dplyr)
require(ggplot2)
require(tidyquant)
require(ggalt)
require(progress)

#------------------Arguments processing-------------------

args <- commandArgs(trailingOnly=TRUE)
selected.topics.path <- args[1]
prefix <- args[2]
lda.reports.folder <- args[3]
text.data.path <- args[4]

#------------------Setting all up-------------------
topic.numbers <- as.numeric(readLines(selected.topics.path))

folder <- sprintf("plots/%s/dynamics/", prefix)
suppressWarnings(dir.create(folder, recursive = TRUE))

doc.topic.path <- paste0(lda.reports.folder, list.files(lda.reports.folder)[1])
topic.labels.path <- paste0(lda.reports.folder, list.files(lda.reports.folder)[2])

pb <- progress_bar$new(
  format = ":spin :topic.number topic  [:bar] :percent Elapsed time: :elapsedfull ETA: :eta",
  total = length(topic.numbers) + 1,
  force = TRUE,
  stream = stdout()
)

for (topic.number in topic.numbers) {
  
  topic.label <- system(sprintf("sed '%dq;d' %s | cut -d ';' -f 3",
                                topic.number + 1,
                                topic.labels.path),
                        intern = TRUE) %>%
    {gsub('\"', "", .)}
  
  pb$tick(tokens = list(topic.number = topic.number))
  
  data.frame(topic.share = system(sprintf("cut -f %d -d ',' %s | sed '1d'", topic.number, doc.topic.path), intern = TRUE),
             n.of.words = system(sprintf("cut -f 4 %s | awk '{print NF}' | sed '1d'", text.data.path), intern = TRUE),
             date = system(sprintf("cut -f 3 %s | sed '1d'", text.data.path), intern = TRUE),
             stringsAsFactors = FALSE) %>% 
    transmute(date = as.numeric(date) %>% # Leave only what is needed for the plot  
                as.POSIXct(origin = "1970-01-01") %>% 
                as.Date() %>%
                format("%Y-%m"),
              n.of.topic.words = as.numeric(n.of.words) * as.numeric(topic.share)) %>%
    group_by(date) %>% 
    summarize(topic = sum(n.of.topic.words)) %>% # Get summary for each month
    filter(date != "2017-08") %>% # Remove not fully downloaded month
    ggplot() +
    geom_xspline(aes(x = date %>% paste0("-01") %>% as.Date, y = topic, group = 1)) +
    scale_x_date(date_breaks = "3 months", date_labels = "%B %Y") + # Formates as Mon YYYY 
    ggtitle(
      label = sprintf("Топик %d", topic.number),
      subtitle = topic.label
    ) +
    theme_tq() +
    theme(
      axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1),
      axis.ticks.x = element_blank(),
      axis.title = element_blank()
    )
  
  ggsave(sprintf("%s%d-topic.png", folder, topic.number), width = 10, height = 5, dpi = 80, units = "in")
}
