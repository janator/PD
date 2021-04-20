#include <iostream>
#include <mpi.h>
#include <stdlib.h>
double Integrate(int x_1, int p, int N) {
  double integral = 0;
  int x_2 = std::min(x_1 + N / p, N);
  x_2 = N - x_2 < N / p ? N : x_2;
  for (int i = x_1; i < x_2; ++i) {
    integral += (4.0 / (1.0 + ((double) i * i / (N * N)))
        + 4.0 / (1.0 + ((double) (i + 1.0) * (i + 1.0) / (N * N)))) / 2 / N;
  }
  return integral;
}
int main(int argc, char *argv[]) {
  int rank, size, x0 = 0;
  MPI_Init(&argc, &argv);
  MPI_Status status;

  int N = atoi(argv[1]);

  MPI_Comm_size(MPI_COMM_WORLD, &size);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  double t0 = MPI_Wtime();
  if (rank == 0) {
    for (int i = 1; i < size; ++i) {
      int x =  N / size * i;
      MPI_Send(&x, 1, MPI_INT, i, 0, MPI_COMM_WORLD);
    }
  } else {
    MPI_Recv(&x0, 1, MPI_DOUBLE, 0, 0, MPI_COMM_WORLD, &status);
  }
  double I_i = Integrate(x0, size, N);
  if (rank != 0) {
    MPI_Send(&I_i, 1, MPI_DOUBLE, 0, 0, MPI_COMM_WORLD);
  } else {
    double I = I_i;
    std::cout << "I1 = " << I_i << std::endl;
    for (int i = 1; i < size; ++i) {
      MPI_Recv(&I_i, 1, MPI_DOUBLE, i, 0, MPI_COMM_WORLD, &status);
      I += I_i;
      std::cout << "I" << i << " = " << I_i << std::endl;
    }
    double t1 = MPI_Wtime() - t0;
    double t2 = MPI_Wtime();
    double I0 = 0;
    for (int i = 0; i < size; ++i) {
      I0 += Integrate(i * N / size, size, N);
    }
    double t3 = MPI_Wtime() - t2;
    std::cout << "S = " << t3 / t1 << std::endl;
    std::cout << "I = " << I << std::endl;
    std::cout << "I0 = " << I0 << std::endl;
    std::cout << "I - I0 = " << I - I0 << std::endl;
  }
  MPI_Finalize();
  return 0;
}