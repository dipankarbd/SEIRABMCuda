#include "kernel.h"
#include "support.h"
#include <stdio.h>


__device__ int getCellId(float x, float y, float cellSize, int gridWidth) {
    int cellX = (int)(x / cellSize);
    int cellY = (int)(y / cellSize);
    return cellX + cellY * gridWidth;
}

// Assigns each agent to a grid cell for spatial partitioning for efficient proximity queries.
__global__ void spatialIndexingKernel(AgentData d_agents, int num_agents, float cell_size,
                                      int grid_width) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < num_agents) {
        d_agents.cellId[idx] = getCellId(d_agents.x[idx], d_agents.y[idx], cell_size, grid_width);
    }
}
