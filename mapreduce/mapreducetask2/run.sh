#!/usr/bin/env bash

OUT_DIR="task2_out"
NUM_REDUCERS=8

# Remove previous results
hdfs dfs -rm -r -skipTrash ${OUT_DIR}.tmp >/dev/null

yarn jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-streaming.jar >/dev/null \
    -D mapreduce.job.name="mapreduce_task2_1" \
    -D mapreduce.job.reduces=$NUM_REDUCERS \
    -files mapper.py,reducer.py \
    -mapper mapper.py \
    -combiner reducer.py \
    -reducer reducer.py \
    -input /data/wiki/en_articles \
    -output ${OUT_DIR}.tmp

hdfs dfs -rm -r -skipTrash ${OUT_DIR} >/dev/null

yarn jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-streaming.jar >/dev/null \
    -D stream.num.map.output.key.fields=2 \
    -D mapreduce.job.name="mapreduce_task2_2" \
    -D mapreduce.job.reduces=1 \
    -D mapreduce.job.output.key.comparator.class=org.apache.hadoop.mapreduce.lib.partition.KeyFieldBasedComparator \
    -D mapreduce.partition.keycomparator.options='-k2,2nr -k1' \
    -mapper cat \
    -reducer cat \
    -input ${OUT_DIR}.tmp \
    -output ${OUT_DIR}

# Checking result
hdfs dfs -cat ${OUT_DIR}/part-00000 | head -n 10


