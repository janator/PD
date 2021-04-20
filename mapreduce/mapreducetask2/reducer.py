#!/usr/bin/env python3

import sys
import re

current_key = None
sum_count = 0
propper_name = True

for line in sys.stdin:
	try:
		key, count = line.strip().split('\t', 1)
		count = int(count)
	except ValueError as e:
		continue

	if current_key != key:
		if current_key and propper_name:
			print ("%s\t%d" % (current_key, sum_count))
		sum_count = 0
		current_key = key
		propper_name = True

	if count == 0:
		propper_name = False

	sum_count += count

if current_key and propper_name:
	print ("%s\t%d" % (current_key, sum_count))
