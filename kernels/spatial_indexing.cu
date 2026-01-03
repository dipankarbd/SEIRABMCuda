#include "kernel.h"
#include "support.h"
#include <stdio.h>

__global__ void spatialIndexingKernel(AgentData d_agents, int num_agents, float cell_size,
                                      int grid_width) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx == 0) {
        printf("TODO: spatialIndexingKernel - Thread 0 executing for agent %d\n", idx);
    }
}
