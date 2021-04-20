import os
import time

bash_template='''#!/bin/bash
#
#SBATCH --ntasks={}
#SBATCH --cpus-per-task=1
#SBATCH --partition=RT
#SBATCH --job-name=example
#SBATCH --comment="Run mpi from config"
#SBATCH --output=out.txt
#SBATCH --error=error.txt
mpiexec ./a.out {}'''

out_file = open("table_out.txt", "a")
N_values = [1000, 10 ** 6, 10 ** 8]
for N in N_values:
    for p in range(1, 9):
        with open("sbatch.sh", "w") as script:
            script.write(bash_template.format(p, N))
        os.system("sbatch sbatch.sh")
        with open("out.txt", "r") as out:
	   temp = out.read()
	   out_file.write("{} {} {}".format(N, p, temp))
        os.system("rm out.txt")
out_file.close()
