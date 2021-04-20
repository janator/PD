#!/usr/bin/env bash

OUT_DIR="streaming_wc_result"
NUM_REDUCERS=5

hadoop fs -rm -r -skipTrash $OUT_DIR >/dev/null

yarn jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-streaming.jar >/dev/null \
    -D mapred.job.name="mapreduce_task1" \
    -D mapreduce.job.reduces=${NUM_REDUCERS} \
    -files mapper.py,reducer.py \
    -mapper mapper.py \
    -reducer reducer.py \
    -input /data/ids \
    -output $OUT_DIR

# Checking result
for num in `seq 0 $(($NUM_REDUCERS - 1))`
do
    hdfs dfs -cat ${OUT_DIR}/part-0000$num | head 
done
