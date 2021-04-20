#include <iostream>
#include <cstdio>


#define LOG_NUM_BANKS 5
#define GET_OFFSET(idx) (idx >> LOG_NUM_BANKS)
#define BLOCK_SIZE 256


__global__
void BlockScan(int* in_data, int* out_data, int* sum, int size) {

  extern __shared__ int shared_data[];

  unsigned int tid = threadIdx.x;
  if (tid < size) {
    shared_data[tid + GET_OFFSET(tid)] = in_data[tid];
  } else {
    shared_data[tid + GET_OFFSET(tid)] = 0;
  }


  __syncthreads();

  for (unsigned int shift = 1; shift < blockDim.x; shift <<= 1 ) {
    int ai = shift * (2 * tid + 1) - 1;
    int bi = shift * (2 * tid + 2) - 1;

    if (bi < blockDim.x) {
      shared_data[bi + GET_OFFSET(bi)] += shared_data[ai + GET_OFFSET(ai)];
    }

    __syncthreads();
  }

  if (tid == 0) {
    sum[0] = shared_data[blockDim.x - 1 + GET_OFFSET(blockDim.x - 1)];
    shared_data[blockDim.x - 1 + GET_OFFSET(blockDim.x- 1)] = 0;
  }

  __syncthreads();

  int temp;
  for (unsigned int shift = blockDim.x / 2; shift > 0; shift >>= 1) {
    int bi = shift * (2 * tid + 2) - 1;
    int ai = shift * (2 * tid + 1) - 1;
    int ai_offset = ai + GET_OFFSET(ai);
    int bi_offset = bi + GET_OFFSET(bi);
    if (bi < blockDim.x) {
      temp = shared_data[ai_offset]; // blue in temp

      shared_data[ai_offset] = shared_data[bi_offset]; // orange

      shared_data[bi_offset] = temp + shared_data[bi_offset];
    }
    __syncthreads();

  }
  out_data[tid] = shared_data[tid + GET_OFFSET(tid)];

  __syncthreads();

}

__global__
void AddInScan(int* in_data, int* sum, int size) {
  unsigned int index = threadIdx.x + blockIdx.x * blockDim.x;
  if (index < size && index >= blockIdx.x) {
    in_data[index] += sum[blockIdx.x];
  }
}

__global__
void MakeFlag(int* in_data, int* less_flag, int* equal_flag, int* greater_flag, int size) {
  unsigned int index = threadIdx.x + blockIdx.x * blockDim.x;
  int pivot = in_data[size - 1];
  if (index < size) {
    less_flag[index] = (int) (in_data[index] < pivot);
    equal_flag[index] = (int) (in_data[index] == pivot);
    greater_flag[index] = (int) (in_data[index] > pivot);
  }
}

void Scan(int* d_array, int* d_localscan, int size, int* d_full_sum) {
  // сканируем массив поблочно
  int num_blocks = size % BLOCK_SIZE == 0 ? size / BLOCK_SIZE : size / BLOCK_SIZE + 1;
  int* d_sum;
  cudaMalloc(&d_sum, sizeof(int) * num_blocks);

  for (int i = 0; i < num_blocks; ++i) {
    int cur_size = BLOCK_SIZE * (i + 1) <= size ? BLOCK_SIZE : size % BLOCK_SIZE;
    BlockScan <<< 1, BLOCK_SIZE, sizeof(int) * (BLOCK_SIZE + GET_OFFSET(BLOCK_SIZE)) >>> (&d_array[i * BLOCK_SIZE],
        &d_localscan[i * BLOCK_SIZE], &d_sum[i], cur_size);
  }

  int* d_sum_out;
  cudaMalloc(&d_sum_out, sizeof(int) * (num_blocks + 1));

  // сканируем суммы в конце блоков, если массив меньше 1^256, то должно влезть в один блок
  // также сохраним конечную сумму, пригодится для размера массивов
  BlockScan <<< 1, BLOCK_SIZE, sizeof(int) * (BLOCK_SIZE + GET_OFFSET(BLOCK_SIZE)) >>> (d_sum, d_sum_out, d_full_sum, num_blocks);

  // Добавляем суммы к массиву префикс сумм
  num_blocks = (size + 1) % BLOCK_SIZE == 0 ? (size + 1) / BLOCK_SIZE : (size + 1) / BLOCK_SIZE + 1;
  AddInScan <<<num_blocks, BLOCK_SIZE>>> (d_localscan, d_sum_out, size + 1);
}

__global__
void Split(int *in_data, int* out_data, int* flag, int size) {
  unsigned int index = threadIdx.x + blockIdx.x * blockDim.x;

  // возможно стоит подгрузить в shared_memory flag
  if (index < size - 1 &&  flag[index] < flag[index + 1]) {
    out_data[flag[index]] = in_data[index];
  }
}
__global__
void Copy(int* d_from_array, int* d_to_array, int size) {
  unsigned int index = threadIdx.x + blockIdx.x * blockDim.x;
  if (index < size) {
    d_to_array[index] = d_from_array[index];
  }
}

void QuickSort(int *d_array, int* d_splited, int size) {
  int num_blocks = size % BLOCK_SIZE == 0 ? size / BLOCK_SIZE : size / BLOCK_SIZE + 1;
  int* d_less_flag;
  cudaMalloc(&d_less_flag, sizeof(int) * size);
  int* d_equal_flag;
  cudaMalloc(&d_equal_flag, sizeof(int) * size);
  int* d_greater_flag;
  cudaMalloc(&d_greater_flag, sizeof(int) * size);

  // делаем массивы сравнений
  MakeFlag <<<num_blocks, BLOCK_SIZE, 1>>> (d_array, d_less_flag, d_equal_flag, d_greater_flag, size);

  // сканируем эти массивы
  int *d_less_flag_scan;
  cudaMalloc(&d_less_flag_scan, sizeof(int) * (size + 1));
  int *d_equal_flag_scan;
  cudaMalloc(&d_equal_flag_scan, sizeof(int) * (size + 1));
  int *d_greater_flag_scan;
  cudaMalloc(&d_greater_flag_scan, sizeof(int) * (size + 1));
  int* d_less_flag_size;
  int* d_equal_flag_size;
  int* d_greater_flag_size;
  cudaMalloc(&d_less_flag_size, sizeof(int));
  cudaMalloc(&d_equal_flag_size, sizeof(int));
  cudaMalloc(&d_greater_flag_size, sizeof(int));

  Scan(d_less_flag, d_less_flag_scan, size, d_less_flag_size);
  int h_less_flag_size, h_equal_flag_size, h_greater_flag_size;
  cudaMemcpy(&h_less_flag_size, d_less_flag_size, sizeof(int), cudaMemcpyDeviceToHost);

  Scan(d_equal_flag, d_equal_flag_scan, size, d_equal_flag_size);
  cudaMemcpy(&h_equal_flag_size, d_equal_flag_size, sizeof(int), cudaMemcpyDeviceToHost);
  Scan(d_greater_flag, d_greater_flag_scan, size, d_greater_flag_size);
  cudaMemcpy(&h_greater_flag_size, d_greater_flag_size, sizeof(int), cudaMemcpyDeviceToHost);

  // перемещаем в наши новые массивы сначала меньшие значения, потом равные, потом большие
  // !!! последний элемент пивот, надо скопировать тоже !!!


  Split <<<num_blocks, BLOCK_SIZE>>> (d_array, d_splited, d_less_flag_scan, size + 1);
  Split <<<num_blocks, BLOCK_SIZE>>> (d_array, &d_splited[h_less_flag_size], d_equal_flag_scan, size + 1);
  Split <<<num_blocks, BLOCK_SIZE>>> (d_array, &d_splited[h_less_flag_size + h_equal_flag_size], d_greater_flag_scan, size + 1);

  int *d_new_splited_less;
  cudaMalloc(&d_new_splited_less, sizeof(int) * h_less_flag_size);

  int *d_new_splited_greater;
  cudaMalloc(&d_new_splited_greater, sizeof(int) * h_greater_flag_size);

  if (h_less_flag_size > 1) {
    QuickSort(d_splited, d_new_splited_less, h_less_flag_size);
    int num_blocks = h_less_flag_size % BLOCK_SIZE == 0 ? h_less_flag_size / BLOCK_SIZE : h_less_flag_size / BLOCK_SIZE + 1;
    Copy<<< num_blocks, BLOCK_SIZE>>> (d_new_splited_less, d_splited, h_less_flag_size);
  }
  if (h_greater_flag_size > 1) {
    QuickSort(&d_splited[h_less_flag_size + h_equal_flag_size], d_new_splited_greater, h_greater_flag_size);
    int num_blocks = h_greater_flag_size % BLOCK_SIZE == 0 ? h_greater_flag_size / BLOCK_SIZE : h_greater_flag_size / BLOCK_SIZE + 1;
    Copy<<< num_blocks, BLOCK_SIZE>>> (d_new_splited_greater, &d_splited[h_equal_flag_size + h_less_flag_size], h_greater_flag_size);
  }
}

int partition (int *a, int p, int r)
{
  int x = *(a+r);
  int i = p - 1;
  int j;
  int tmp;
  for (j = p; j < r; j++)
  {
    if (*(a+j) <= x)
    {
      i++;
      tmp = *(a+i);
      *(a+i) = *(a+j);
      *(a+j) = tmp;
    }
  }
  tmp = *(a+r);
  *(a+r) = *(a+i+1);
  *(a+i+1) = tmp;
  return i + 1;
}

void SlowQuicksort (int *a, int p, int r)
{
  int q;
  if (p < r)    {
    q = partition (a, p, r);
    SlowQuicksort (a, p, q-1);
    SlowQuicksort (a, q+1, r);
  }
}

int main() {
  const int block_size = 256;
  cudaEvent_t start;
  cudaEvent_t stop;

  // Creating event
  cudaEventCreate(&start);
  cudaEventCreate(&stop);

  const int array_size = 1024;
  int* h_array = new int[array_size];
  for (int i = 0; i < array_size; ++i) {
    h_array[i] = i % 4;
  }
  int* d_array;

  cudaMalloc(&d_array, sizeof(int) * array_size);
  cudaMemcpy(d_array, h_array, sizeof(int) * array_size, cudaMemcpyHostToDevice);

  int* d_sorted;
  cudaMalloc(&d_sorted, sizeof(int) * array_size);
  cudaEventRecord(start);

  QuickSort(d_array, d_sorted, array_size);

  cudaEventRecord(stop);
  cudaEventSynchronize(stop);
  float milliseconds = 0;
  cudaEventElapsedTime(&milliseconds, start, stop);
  std::cout << milliseconds << " elapsed fast" << std::endl;
  cudaEvent_t start2;
  cudaEvent_t stop2;
  cudaEventCreate(&start2);
  cudaEventCreate(&stop2);
  cudaEventRecord(start2);

  SlowQuicksort(h_array, 0, array_size);

  cudaEventRecord(stop2);
  cudaEventSynchronize(stop2);
  milliseconds = 0;
  cudaEventElapsedTime(&milliseconds, start2, stop2);
  std::cout << milliseconds << " elapsed slow" << std::endl;


  int* h_sorted = new int[array_size];
  cudaMemcpy(h_sorted, d_sorted, sizeof(int) * array_size, cudaMemcpyDeviceToHost);

  delete[] h_array;
  delete[] h_sorted;

}
