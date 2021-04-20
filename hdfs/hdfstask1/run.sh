#!/usr/bin/env bash

ip=$(hdfs fsck $1 -files -blocks -locations | egrep -o 'DatanodeInfoWithStorage\[[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}' | head -1)

echo ${ip:24}
