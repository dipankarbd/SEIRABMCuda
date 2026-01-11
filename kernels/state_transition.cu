#include "kernel.h"
#include "support.h"
#include "types.h"
#include <stdio.h>

// Transitions agents from one SEIR state to the next based on timers.
// This kernel updates the SEIR state of each agent in parallel. It is responsible
// for the progression of the disease within an infected individual.
__global__ void stateTransitionKernel(AgentData d_agents, int num_agents, float timestep,
                                      float infectious_mean, float infectious_std) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx == 0) {
        printf("TODO: stateTransitionKernel - Thread 0 executing for agent %d\n", idx);
    }
}