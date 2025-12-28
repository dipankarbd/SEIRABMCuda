#ifndef KERNEL_H
#define KERNEL_H

#include "types.h"
#include <cuda_runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

__global__ void agentInitializationKernel(AgentData d_agents, int num_agents);
__global__ void agentMovementKernel(AgentData d_agents, int num_agents);
__global__ void spatialIndexingKernel(AgentData d_agents, int num_agents);
__global__ void diseaseTransmissionKernel(AgentData d_agents, int num_agents);
__global__ void stateTransitionKernel(AgentData d_agents, int num_agents);
__global__ void statisticsCollectionKernel(AgentData d_agents, int num_agents);

#ifdef __cplusplus
}
#endif

#endif // KERNEL_H
