#!/usr/bin/env python3

import sys
import re

pattern1 = re.compile(r'\b[A-Z][a-z]{5,8}\b')
pattern2 = re.compile(r'\b[a-z]{6,9}\b')

for line in sys.stdin:
	try:
		article_id, text = line.strip().split('\t', 1)
	except ValueError as e:
		continue
	words1 = re.findall(pattern1, text)
	words2 = re.findall(pattern2, text)
	for word in words1:
		print("%s\t%d" % (word.lower(), 1))
	for word in words2:
		print("%s\t%d" % (word.lower(), 0))
