#include "kernel.h"
#include "support.h"
#include <cuda_runtime.h>

// Collects statistics on the number of agents in each SEIR state in parallel.
// This kernel uses a parallel reduction algorithm to efficiently count the number of agents
// in each state (Susceptible, Exposed, Infectious, Recovered).
__global__ void statisticsCollectionKernel(AgentData d_agents, int num_agents,
                                           Statistics *d_stats) {
    __shared__ int s_susceptible[BLOCK_SIZE];
    __shared__ int s_exposed[BLOCK_SIZE];
    __shared__ int s_infectious[BLOCK_SIZE];
    __shared__ int s_recovered[BLOCK_SIZE];

    int tid = threadIdx.x;
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    s_susceptible[tid] = 0;
    s_exposed[tid] = 0;
    s_infectious[tid] = 0;
    s_recovered[tid] = 0;

    if (idx < num_agents) {
        switch (d_agents.state[idx]) {
        case SUSCEPTIBLE:
            s_susceptible[tid] = 1;
            break;
        case EXPOSED:
            s_exposed[tid] = 1;
            break;
        case INFECTIOUS:
            s_infectious[tid] = 1;
            break;
        case RECOVERED:
            s_recovered[tid] = 1;
            break;
        }
    }
    __syncthreads();

    for (unsigned int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_susceptible[tid] += s_susceptible[tid + s];
            s_exposed[tid] += s_exposed[tid + s];
            s_infectious[tid] += s_infectious[tid + s];
            s_recovered[tid] += s_recovered[tid + s];
        }
        __syncthreads();
    }

    if (tid == 0) {
        atomicAdd(&d_stats->susceptible, s_susceptible[0]);
        atomicAdd(&d_stats->exposed, s_exposed[0]);
        atomicAdd(&d_stats->infectious, s_infectious[0]);
        atomicAdd(&d_stats->recovered, s_recovered[0]);
    }
}