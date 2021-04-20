import re 
from pyspark import SparkContext, SparkConf 

conf = SparkConf().setAppName("task1").setMaster("yarn") 
sc = SparkContext(conf=conf) 

rdd = sc.textFile("/data/wiki/en_articles_part") 
rdd = rdd.map(lambda x: x.strip().lower()) 

rdd = rdd.map(lambda x: re.sub("narodnaya\W+", "narodnaya_", x)) 
rdd = rdd.flatMap(lambda x: x.split(" "))
rdd = rdd.map(lambda x: re.sub("^\W+|\W+$", "", x)) 
rdd = rdd.filter(lambda x: "narodnaya" in x) 
rdd = rdd.map(lambda x: (x, 1)) 
rdd = rdd.reduceByKey(lambda x, y: x + y) 
rdd = rdd.sortByKey(ascending=True) 

final = rdd.collect() 
for word_pair, count in final: 
    print word_pair, count
