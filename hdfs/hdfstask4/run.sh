#!/usr/bin/env bash

node=$(hdfs fsck -blockId $1 | egrep -o "mipt-node[[:digit:]]+.atp-fivt.org" | head -1)
adr="hdfsuser@${node}"
path=$(sudo -u hdfsuser ssh $adr find /dfs -name $1)
full_path="${node}:$path"
echo "$full_path"