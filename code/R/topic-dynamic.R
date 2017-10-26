# Load doc-topic matrix -> get needed topic column
# Load data, get time column (system with cut to save time?)
# Get N of words for each text (cut | wc ?)
# Cbind three columns
# Group by month
# Calculate N of words for each month for given topic

topic.numbers <- readLines()
# Is it better to iterate over loaded matrix? Or cut it in shell?
doc.topic.matrix <- data.table::fread("lda-reports/chelni/300-topics/chelni-300-doc-topics.csv")[, topic.number]
n.of.words <- system("cut -f 4 data/data-chelni-sample-processed.tsv | awk {print NF}")
