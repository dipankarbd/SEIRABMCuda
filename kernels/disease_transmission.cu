#include "kernel.h"
#include "support.h"
#include <stdio.h>

// Simulates the transmission of the disease between agents in parallel.
// This kernel is the core of the epidemic simulation. It models the spread of the
// disease from infectious agents to susceptible agents.
__global__ void diseaseTransmissionKernel(AgentData d_agents, int num_agents, int grid_width,
                                          int grid_height, float contact_radius,
                                          float incubation_mean, float incubation_std,
                                          float transmission_prob) {

    __shared__ float s_x[NUM_AGENTS_PER_BATCH];
    __shared__ float s_y[NUM_AGENTS_PER_BATCH];
    __shared__ unsigned int s_state[NUM_AGENTS_PER_BATCH];
    __shared__ int s_agentIdx[NUM_AGENTS_PER_BATCH];

    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int tid = threadIdx.x;

    if (idx >= num_agents) {
        return;
    }

    curandState rngState = d_agents.rngStates[idx];

    float x1 = d_agents.x[idx];
    float y1 = d_agents.y[idx];

    int cellId = d_agents.cellId[idx];
    int cellX = cellId % grid_width;
    int cellY = cellId / grid_width;

    float contactRadiusSq = contact_radius * contact_radius;
    bool isInfectious = (d_agents.state[idx] == INFECTIOUS);

    for (int batchStart = 0; batchStart < num_agents; batchStart += NUM_AGENTS_PER_BATCH) {
        int batchSize = min(NUM_AGENTS_PER_BATCH, num_agents - batchStart);

        if (tid < batchSize) {
            int loadIdx = batchStart + tid;
            s_x[tid] = d_agents.x[loadIdx];
            s_y[tid] = d_agents.y[loadIdx];
            s_state[tid] = d_agents.state[loadIdx];
            s_agentIdx[tid] = loadIdx;
        }

        __syncthreads();

        if (isInfectious) {
            for (int i = 0; i < batchSize; i++) {
                if (s_agentIdx[i] == idx) {
                    continue;
                }

                if (s_state[i] != SUSCEPTIBLE) {
                    continue;
                }

                int otherCellId = d_agents.cellId[s_agentIdx[i]];
                int otherCellX = otherCellId % grid_width;
                int otherCellY = otherCellId / grid_width;

                int cellDx = abs(cellX - otherCellX);
                int cellDy = abs(cellY - otherCellY);

                if (cellDx > 1 || cellDy > 1) {
                    continue;
                }

                float dx2 = x1 - s_x[i];
                float dy2 = y1 - s_y[i];
                float distSq = dx2 * dx2 + dy2 * dy2;

                if (distSq <= contactRadiusSq) {
                    if (curand_uniform(&rngState) < transmission_prob) {
                        unsigned int previousState =
                            atomicCAS(&d_agents.state[s_agentIdx[i]], SUSCEPTIBLE, EXPOSED);

                        if (previousState == SUSCEPTIBLE) {
                            float incubationTime =
                                gaussianRandom(&rngState, incubation_mean, incubation_std);
                            d_agents.stateTimer[s_agentIdx[i]] = fmaxf(1.0f, incubationTime);
                        }
                    }
                }
            }
        }

        __syncthreads();
    }

    d_agents.rngStates[idx] = rngState;
}