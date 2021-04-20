#!/usr/bin/env python3

import sys
import random

random.seed(42)

for id in sys.stdin:
	print ("%d\t%s" % (random.randint(1, 100), id.strip()))
