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

    if (idx < num_agents) {
        unsigned int state = d_agents.state[idx];

        if (state == SUSCEPTIBLE || state == RECOVERED) {
            return;
        }

        float stateTimer = d_agents.stateTimer[idx];
        stateTimer -= timestep;

        if (stateTimer <= 0.0f) {
            curandState rngState = d_agents.rngStates[idx];

            if (state == EXPOSED) {
                state = INFECTIOUS;
                float infectiousTime = gaussianRandom(&rngState, infectious_mean, infectious_std);
                stateTimer = fmaxf(1.0f, infectiousTime);
            } else if (state == INFECTIOUS) {
                state = RECOVERED;
                stateTimer = 0.0f;
            }

            d_agents.rngStates[idx] = rngState;
        }

        d_agents.state[idx] = state;
        d_agents.stateTimer[idx] = stateTimer;
    }
}