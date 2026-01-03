#ifndef SUPPORT_H
#define SUPPORT_H

#include <cuda_runtime.h>
#include <curand_kernel.h>

void checkCudaError(cudaError_t cudaStat, const char *msg);

__device__ float gaussianRandom(curandState *state, float mean, float std);

#endif // SUPPORT_H