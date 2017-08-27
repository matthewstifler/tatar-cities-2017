#!/usr/bin/env python

#Usage python code/ .py [Path to directory with doc-topics] [Path to text source file: text in "text" column] [Prefix for top-texts]

import sys, os, errno, time
import numpy as np
import pandas as pd

#---------Functions definitions------------

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise

# Get paths for all files in given folder, including all nested folders
def list_files_recursive(path):
    files_list = []
  
    # Get list of files for each directory:
    for root, dirs, files in os.walk(path):
        current_dir_file_list = []
    
        # Turn each file name into a path to it
        for file in files: 
            current_dir_file_list.append(os.path.join(root, file))
    
        files_list.extend(current_dir_file_list)
  
    return files_list

# Get paths for all files in given folder, including all nested folders that match given pattern
def fetch_docs_by_pattern(path, pattern):
    filenames = list_files_recursive(path)
    
    files = [filename for filename in filenames if filename.find(pattern) > 0]
  
    return files

# Returns docs from given csv with "text" column, according to how much of given topic is contained in given doc
def get_top_texts_for_topic(doc_topic_matrix, text_data, topic_number, texts_number):
    col = doc_topic_matrix.ix[:,topic_number - 1].copy()
    col.sort(ascending=False)
    
    return text_data["text"][col.head(texts_number).index]

#-------------------

def main():
    start_time = time.time()
    # Load data
    DOC_TOPIC_PATH = sys.argv[1]
    TEXT_DATA = pd.read_csv(sys.argv[2], sep = "\t", quoting = 3, names = ["author.id", "post.id", "date", "text"], skiprows = 1) # Hacks, hacks everywhere
    OUTPUT_PATH = os.path.join("top-texts", sys.argv[3])
    
    mkdir_p(OUTPUT_PATH)
    
    doc_topic_files = fetch_docs_by_pattern(DOC_TOPIC_PATH, "doc-topics")
    
    # For each topic in each doc-topic matrix get top texts and save to a .txt
    for doc_topic in doc_topic_files:
        doc_topic_matrix = pd.read_csv(doc_topic)
        
        n_of_topics = doc_topic_matrix.shape[1]
        
        current_path = os.path.join(OUTPUT_PATH, str(n_of_topics) + "-topics")
        mkdir_p(current_path)
        
        for j in range(1, n_of_topics):
            texts = get_top_texts_for_topic(doc_topic_matrix, TEXT_DATA, j, 50)
            np.savetxt(os.path.join(current_path, str(j) + ".txt"), texts, fmt = "%s")
        
        print doc_topic + " processed at " + time.strftime("%X")
    
    total_time = time.time() - start_time
    print "Total time elapsed: " + str(total_time)

#-------------------
if __name__ == "__main__":
  main()
