#ifndef KERNEL_H
#define KERNEL_H

#include "types.h"
#include <cuda_runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

__global__ void agentInitializationKernel(AgentData d_agents, int num_agents, unsigned long seed,
                                          float world_width, float world_height,
                                          float movement_speed);
__global__ void agentMovementKernel(AgentData d_agents, int num_agents, float world_width,
                                    float world_height, float movement_speed,
                                    float mobility_reduction, float home_return_probability,
                                    float timestep);
__global__ void spatialIndexingKernel(AgentData d_agents, int num_agents, float cell_size,
                                      int grid_width);
__global__ void diseaseTransmissionKernel(AgentData d_agents,
                                          unsigned int *d_infectious_agent_indices,
                                          int num_infected_agents, int num_agents, int grid_width,
                                          int grid_height, float contact_radius,
                                          float incubation_mean, float incubation_std,
                                          float transmission_prob);
__global__ void stateTransitionKernel(AgentData d_agents, int num_agents, float timestep,
                                      float infectious_mean, float infectious_std);
__global__ void statisticsCollectionKernel(AgentData d_agents, int num_agents, Statistics *d_stats);

#ifdef __cplusplus
}
#endif

#endif // KERNEL_H
