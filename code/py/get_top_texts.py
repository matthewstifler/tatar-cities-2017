#!/usr/bin/env python

#Usage python code/get_top_texts.py [Path to directory with doc-topics] [Path to text source file: text in "text" column] [Path to vk token file] [Prefix for top-texts]

import sys, os, errno, time, requests
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

# Simple function to get group types by their ids
def get_groups_types(group_ids, vk_token):
    request_params = {'access_token': vk_token, 'group_ids': ','.join(str(id).replace('-', '') for id in group_ids)}
    vk_response = requests.get('https://api.vk.com/method/groups.getById', params = request_params).json()['response']
    
    output = []
    
    for i in range(0, len(vk_response)):
      if vk_response[i]['type'] == 'page':
        output.append('public')
      else:
        output.append('club')
      
    return output

# Generate a vector of group types, to concatenate later into URLs
def generate_vk_post_links(group_type_dict, dataframe):
  links = []
  
  for index, row in dataframe.iterrows():
    links.append('https://vk.com/' + group_type_dict[row['author.id']] + str(row['author.id']).replace('-', '') + '?w=wall' + str(row['author.id']) + '_' + str(row['post.id']))
  
  return links

# Returns docs from given csv with "text" column, according to how much of given topic is contained in given doc
def get_top_texts_for_topic(doc_topic_matrix, topic_labels, text_data, topic_number, texts_number, groups_types_dict):
    # Get needed doc-topic matrix column and sort it
    col = doc_topic_matrix.ix[:, topic_number - 1].copy()
    col.sort(ascending=False)
    
    # Get indices of 50 top values from previous step, get according rows from source dataframe
    output = text_data.iloc[col.head(texts_number).index]
    output.loc[:,'date'] = pd.to_datetime(output['date'], unit='s')
    
    # Construct VK links
    links = generate_vk_post_links(groups_types_dict, output)
    
    output['link'] = links
    output['topic.weight'] = col.head(texts_number)
    output['topic.label'] = topic_labels[topic_number - 1]
    
    
    return output[['author.id', 'post.id', 'date', 'link', 'topic.label', 'topic.weight', 'text']]

#-------------------

def main():
    start_time = time.time()
    # Load data
    DOC_TOPIC_PATH = sys.argv[1]
    TEXT_DATA = pd.read_csv(sys.argv[2], sep = "\t", quoting = 3, names = ["author.id", "post.id", "date", "text"], skiprows = 1) # Hacks, hacks everywhere
    VK_TOKEN = open('code/config/vk-token', 'r').read()
    OUTPUT_PATH = os.path.join("top-texts", sys.argv[4])
    
    # Setup output
    mkdir_p(OUTPUT_PATH)
    
    # Get matching files
    doc_topic_files = fetch_docs_by_pattern(DOC_TOPIC_PATH, "doc-topics")
    topic_labels_files = fetch_docs_by_pattern(DOC_TOPIC_PATH, "topic-labels")
    
    # Get types of groups
    group_ids = TEXT_DATA ['author.id'].unique().tolist()
    groups_types_dict = dict(zip(group_ids, get_groups_types(group_ids, VK_TOKEN)))
    
    # For each topic in each doc-topic matrix get top texts, add links and save to a .tsv file
    for doc_topic, topic_label in zip(doc_topic_files, topic_labels_files):
        doc_topic_matrix = pd.read_csv(doc_topic)
        topic_labels = pd.read_csv(topic_label, sep = ";")["label"]
        
        n_of_topics = doc_topic_matrix.shape[1]
        
        current_path = os.path.join(OUTPUT_PATH, str(n_of_topics) + "-topics")
        mkdir_p(current_path)
        
        for j in range(1, n_of_topics):
            texts = get_top_texts_for_topic(doc_topic_matrix, topic_labels, TEXT_DATA, j, 50, groups_types_dict)
            texts.to_csv(os.path.join(current_path, str(j) + "-topic" + ".tsv"), sep = "\t", header = False, index = False)
        
        print doc_topic + " processed at " + time.strftime("%X")
    
    total_time = time.time() - start_time
    print "Total time elapsed: " + str(total_time)

#-------------------
if __name__ == "__main__":
  main()
