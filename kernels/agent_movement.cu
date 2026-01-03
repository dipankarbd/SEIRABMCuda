#include "kernel.h"
#include <curand_kernel.h>
#include <stdio.h>

__global__ void agentMovementKernel(AgentData d_agents, int num_agents, float world_width,
                                    float world_height, float movement_speed,
                                    float home_return_probability, float timestep) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx == 0) {
        printf("TODO: agentMovementKernel - Thread 0 executing for agent %d\n", idx);
    }
}