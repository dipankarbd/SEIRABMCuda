#include "kernel.h"
#include "types.h"
#include <curand_kernel.h>
#include <stdio.h>

// Initializes the state of each agent in parallel.
// This kernel is responsible for setting the initial properties of each agent at the beginning
// of the simulation. Each thread initializes one agent.
__global__ void agentInitializationKernel(AgentData d_agents, int num_agents, unsigned long seed,
                                          float world_width, float world_height,
                                          float movement_speed) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < num_agents) {
        curandState rngState = d_agents.rngStates[idx];
        curand_init(seed, idx, 0, &rngState);

        d_agents.x[idx] = curand_uniform(&rngState) * world_width;
        d_agents.y[idx] = curand_uniform(&rngState) * world_height;

        d_agents.homeX[idx] = d_agents.x[idx];
        d_agents.homeY[idx] = d_agents.y[idx];

        float angle = curand_uniform(&rngState) * 2.0f * M_PI;
        d_agents.vx[idx] = cosf(angle) * movement_speed;
        d_agents.vy[idx] = sinf(angle) * movement_speed;

        d_agents.state[idx] = SUSCEPTIBLE;
        d_agents.stateTimer[idx] = 0;

        d_agents.rngStates[idx] = rngState;
    }
}
