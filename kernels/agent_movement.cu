#include "kernel.h"
#include <curand_kernel.h>
#include <stdio.h>

// Updates the position of each agent in parallel based on its velocity and behavior.
// This kernel is responsible for the movement of agents within the simulation world.
// Each thread updates one agent's position and velocity.
__global__ void agentMovementKernel(AgentData d_agents, int num_agents, float world_width,
                                    float world_height, float movement_speed,
                                    float mobility_reduction, float home_return_probability,
                                    float timestep) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < num_agents) {
        float effectiveSpeed = movement_speed * (1.0f - mobility_reduction);

        curandState rngState = d_agents.rngStates[idx];

        float x = d_agents.x[idx];
        float y = d_agents.y[idx];
        float vx = d_agents.vx[idx];
        float vy = d_agents.vy[idx];

        if (curand_uniform(&rngState) < home_return_probability) {
            float dx = d_agents.homeX[idx] - x;
            float dy = d_agents.homeY[idx] - y;
            float dist = sqrtf(dx * dx + dy * dy);

            if (dist > 0.1f) {
                vx = (dx / dist) * effectiveSpeed;
                vy = (dy / dist) * effectiveSpeed;
            }
        } else if (curand_uniform(&rngState) < 0.1f) {
            float angle = curand_uniform(&rngState) * 2.0f * M_PI;
            vx = cosf(angle) * effectiveSpeed;
            vy = sinf(angle) * effectiveSpeed;
        }

        x += vx * timestep;
        y += vy * timestep;

        if (x < 0.0f) {
            x += world_width;
        } else if (x >= world_width) {
            x -= world_width;
        }

        if (y < 0.0f) {
            y += world_height;
        } else if (y >= world_height) {
            y -= world_height;
        }

        d_agents.x[idx] = x;
        d_agents.y[idx] = y;
        d_agents.vx[idx] = vx;
        d_agents.vy[idx] = vy;
        d_agents.rngStates[idx] = rngState;
    }
}