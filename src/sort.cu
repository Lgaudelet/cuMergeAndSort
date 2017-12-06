#include <sort.h>

__host__ __device__ void bubbleSort(int* array, int size) {
      bool swapped = true;
      int j = 0;
      int tmp;
      while(swapped) {
            swapped = false;
            j++;
            for(int i=0; i<size-j; i++) {
                  if(array[i] > array[i+1]) {
                        tmp = array[i];
                        array[i] = array[i+1];
                        array[i+1] = tmp;
                        swapped = true;
                  }
            }
      }
}

__global__ void initial_sort(int* array, int size, int grain_size) {

	int tid = blockIdx.x*blockDim.x + threadIdx.x; // thread ID
	int index = tid*grain_size;

	while(index < size) {
		int n = (index+grain_size>size)? grain_size-index+size:grain_size;
		bubbleSort(array+index,n);
		index+=gridDim.x*blockDim.x*grain_size;
	}
}

__global__ void parallel_merge(int* input_array, int size, int* output_array, int subarray_size, int part_size) {
	
	int tid = blockIdx.x*blockDim.x + threadIdx.x;
	int nPartitions = ceil((float)subarray_size/part_size);
	
	int shift_A = 2*tid*subarray_size;
	int shift_B = (2*tid+1)*subarray_size;

	int na = subarray_size;
	int nb = (shift_B+subarray_size>size)? size-shift_B:subarray_size;

	printf("[%d] shift_A:%d na:%d shift_B:%d nb:%d nPart:%d\n", tid, shift_A, na, shift_B, nb, nPartitions);
	partition2<<<1,nPartitions>>>(input_array+shift_A, na, input_array+shift_B, nb, output_array+shift_A); 

}


void msWrapper(int* input_array, int size, int* output_array, int grain_exp) {

	int p = nextpow2(size) - grain_exp;
	if(p<0) {
		std::cout << "input array is too small for specified grain" << std::endl;
		exit(-1);
	}
	
	std::cout << "p+grain "<< p << "+" << grain_exp << std::endl;
	int *tmp, *tmp2;
	int subarray_size = std::pow(2,grain_exp);

	// initial sorting of the array
	cudaMalloc(&tmp, size*sizeof(int));
	cudaMemcpy(tmp, input_array, size*sizeof(int), cudaMemcpyHostToDevice);

	std::cout << "initial_sort:" << subarray_size << std::endl;
	initial_sort<<<1, std::ceil((float)size/subarray_size)>>>(tmp, size, subarray_size);

	int* test = (int*)malloc(size*sizeof(int));
	cudaMemcpy(test, tmp, size*sizeof(int), cudaMemcpyDeviceToHost);
	print_array(test, size);
	free(test);

	// merging arrays two by two until complete sorting
	while(p>0) {
	
		cudaMalloc(&tmp2, size*sizeof(int));

		std::cout << "parallel_merge: " << 1 << " x " << p << std::endl;
		parallel_merge <<<1,p>>> (tmp, size, tmp2, subarray_size);

		int* test = (int*)malloc(size*sizeof(int));
		cudaMemcpy(test, tmp2, size*sizeof(int), cudaMemcpyDeviceToHost);
		print_array(test, size);
		free(test);

		cudaFree(tmp);
		tmp = tmp2;

		subarray_size<<=1;	
		p >>= 1; //divides p by 2
	}
	
	cudaDeviceSynchronize();
	cudaMemcpy(output_array, tmp, size*sizeof(int), cudaMemcpyDeviceToHost);

}

