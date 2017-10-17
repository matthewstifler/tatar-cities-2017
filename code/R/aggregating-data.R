require(dplyr)
require(lubridate)
require(tidyr)

text.data <- read.delim("data/data-elabuga-processed.tsv", stringsAsFactors = FALSE, quote = "")
colnames(text.data) <- c("author.id", "post.id", "date", "text")

#---------------------------------------
# Thresholding share of topic for each one

text.data$text <- gsub('\"', "", text.data$text)
text.data$post.length <- strsplit(text.data$text, " ") %>%
  sapply(length)

# Turning date into year-month pairs
text.data$date <- as.POSIXct(text.data$date, origin = "1970-01-01 00:00:00")
text.data$month <- month(text.data$date)
text.data$year <- year(text.data$date)
text.data$yearmonth <- paste(text.data$year, text.data$month, sep = "-")

doc.topic <- read.csv("lda-reports/elabuga/300-topics/elabuga-300-doc-topics.csv")
doc.topic <- ifelse(doc.topic > 0.2, 1, 0)

elabuga.data <- cbind(text.data, doc.topic)

# Summarising
month.summary <- elabuga.data %>%
  group_by(yearmonth) %>%
  select(starts_with("topic")) %>%
  summarise_all(sum)
  
month.summary$post.sum <- rowSums(month.summary[, -1])
month.summary <- select(month.summary, yearmonth, post.sum, starts_with("topic"))

month.summary[, 3:length(month.summary)] <- apply(month.summary, 1, function(row) {
  as.numeric(row[3:length(row)]) / as.numeric(row[2])
})

month.summary <- gather(month.summary, topic, share, starts_with("topic"))

#---------------------------------------
# Replacing binary var with word counts
elabuga.data.word.counts <- elabuga.data
elabuga.data.word.counts <- select(elabuga.data.word.counts, author.id:text, month:yearmonth, post.length, starts_with("topic"))
elabuga.data.word.counts[,9:ncol(elabuga.data.word.counts)] <- apply(elabuga.data.word.counts, 1, function(row) {
  as.numeric(ifelse(row[9:ncol(elabuga.data.word.counts)] == 1, row["post.length"], 0))
}) %>% t()

month.summary.word.counts <- elabuga.data.word.counts %>%
  group_by(yearmonth) %>%
  select(starts_with("topic")) %>%
  summarise_all(sum) %>% 
  gather(topic, word.count, starts_with("topic"))

month.summary <- left_join(month.summary, month.summary.word.counts, c("yearmonth" = "yearmonth", "topic" = "topic")) %>% 
  select(-post.sum)

write.csv(month.summary, "output/elabuga-summarised/300-topics-by-month.csv")