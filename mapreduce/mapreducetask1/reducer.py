#!/usr/bin/env python3
import random
import sys

random.seed(42)
current_line = ""
num = random.randint(1, 5)

for line in sys.stdin:
    try:
        count, key = line.strip().split('\t', 1)
    except ValueError as e:
        continue
    
    if num > 1:
    #добавляем к строчке которую потом выведем
        current_line += key + ","
        num -= 1
    else:
        num = random.randint(1, 5)
        print (current_line + key)
        current_line = ""

print(current_line.strip(','))
