# Load doc-topic matrix -> get needed topic column
# Load data, get time column (system with cut to save time?)
# Get N of words for each text (cut | wc ?)
# Cbind three columns
# Group by month
# Calculate N of words for each month for given topic

topic.numbers <- readLines("misc/chosen-topics/chelni/300-topics")
# Is it better to iterate over loaded matrix? Or cut it in shell?
doc.topic.matrix <- data.table::fread("lda-reports/chelni/300-topics/chelni-300-doc-topics.csv")[, topic.number]

test <- data.frame(topic.share = system("cut -f 1 -d ',' lda-reports/chelni/300-topics/chelni-300-doc-topics.csv | sed '1d'", intern = TRUE),
           n.of.words = system("cut -f 4 data/data-chelni-sample-processed.tsv | awk '{print NF}' | sed '1d'", intern = TRUE),
           date = system("cut -f 3 data/data-chelni-sample-processed.tsv | sed '1d'", intern = TRUE),
           stringsAsFactors = FALSE) %>% 
  mutate(topic.share = as.numeric(topic.share),
         n.of.words = as.numeric(n.of.words),
         date = as.numeric(date) %>% 
           as.POSIXct(origin = "1970-01-01") %>% 
           as.Date() %>%
           format("%Y-%m"))

