#include "support.h"
#include <stdio.h>
#include <stdlib.h>

void checkCudaError(cudaError_t cudaStat, const char *msg) {
    if (cudaStat != cudaSuccess) {
        fprintf(stderr, "%s failed: %s\n", msg, cudaGetErrorString(cudaStat));
        exit(EXIT_FAILURE);
    }
}

__device__ float gaussianRandom(curandState *state, float mean, float std) {
    float u1 = curand_uniform(state);
    float u2 = curand_uniform(state);
    float z0 = sqrtf(-2.0f * logf(u1)) * cosf(2.0f * M_PI * u2);
    return z0 * std + mean;
}
