#ifndef SUPPORT_H
#define SUPPORT_H

#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>

// Helper function to check CUDA errors
void checkCudaError(cudaError_t cudaStat, const char *msg) {
    if (cudaStat != cudaSuccess) {
        fprintf(stderr, "%s failed: %s\n", msg, cudaGetErrorString(cudaStat));
        exit(EXIT_FAILURE);
    }
}

#endif // SUPPORT_H
