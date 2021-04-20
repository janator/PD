#!/usr/bin/env bash
adress="http://mipt-master.atp-fivt.org:50070/webhdfs/v1${1}?op=OPEN&length=10"

curl -i -L "$adress" | tail -c 10