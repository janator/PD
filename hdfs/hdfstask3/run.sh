#!/usr/bin/env bash

out=$(hdfs fsck -blocks $1  | grep "Total blocks (validated)")

echo "$out" | egrep -o "[[:digit:]]+" | head -1

