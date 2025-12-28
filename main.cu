#include "config_loader.h"
#include "kernels/kernel.h"
#include "support.h"
#include "types.h"
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {
    printf("\nGPU-Accelerated Agent-Based SEIR Epidemic Simulation...\n");

    SimulationConfig h_config;
    load_simulation_config("config.json", &h_config);

    AgentData d_agents;

    int num_agents = h_config.simulation.num_agents;
    cudaError_t cudaStat;

    printf("Allocating memory for %d agents on GPU...\n", num_agents);

    // Allocate memory for each member of AgentData on the device
    cudaStat = cudaMalloc((void **)&d_agents.x, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.x");
    cudaStat = cudaMalloc((void **)&d_agents.y, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.y");
    cudaStat = cudaMalloc((void **)&d_agents.homeX, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.homeX");
    cudaStat = cudaMalloc((void **)&d_agents.homeY, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.homeY");
    cudaStat = cudaMalloc((void **)&d_agents.vx, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.vx");
    cudaStat = cudaMalloc((void **)&d_agents.vy, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.vy");
    cudaStat = cudaMalloc((void **)&d_agents.state, num_agents * sizeof(uint8_t));
    checkCudaError(cudaStat, "cudaMalloc d_agents.state");
    cudaStat = cudaMalloc((void **)&d_agents.stateTimer, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.stateTimer");
    cudaStat = cudaMalloc((void **)&d_agents.cellId, num_agents * sizeof(unsigned int));
    checkCudaError(cudaStat, "cudaMalloc d_agents.cellId");
    cudaStat = cudaMalloc((void **)&d_agents.rngStates, num_agents * sizeof(curandState));
    checkCudaError(cudaStat, "cudaMalloc d_agents.rngStates");

    printf("Memory allocation successful. Proceeding with simulation...\n");

    // Determine grid and block dimensions
    int threadsPerBlock = 256;
    int numBlocks = (num_agents + threadsPerBlock - 1) / threadsPerBlock;

    printf("Launching agentInitializationKernel...\n");
    agentInitializationKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents);
    checkCudaError(cudaGetLastError(), "agentInitializationKernel launch");
    checkCudaError(cudaDeviceSynchronize(), "agentInitializationKernel synchronization");

    printf("Launching agentMovementKernel...\n");
    agentMovementKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents);
    checkCudaError(cudaGetLastError(), "agentMovementKernel launch");
    checkCudaError(cudaDeviceSynchronize(), "agentMovementKernel synchronization");

    printf("Launching spatialIndexingKernel...\n");
    spatialIndexingKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents);
    checkCudaError(cudaGetLastError(), "spatialIndexingKernel launch");
    checkCudaError(cudaDeviceSynchronize(), "spatialIndexingKernel synchronization");

    printf("Launching diseaseTransmissionKernel...\n");
    diseaseTransmissionKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents);
    checkCudaError(cudaGetLastError(), "diseaseTransmissionKernel launch");
    checkCudaError(cudaDeviceSynchronize(), "diseaseTransmissionKernel synchronization");

    printf("Launching stateTransitionKernel...\n");
    stateTransitionKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents);
    checkCudaError(cudaGetLastError(), "stateTransitionKernel launch");
    checkCudaError(cudaDeviceSynchronize(), "stateTransitionKernel synchronization");

    printf("Launching statisticsCollectionKernel...\n");
    statisticsCollectionKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents);
    checkCudaError(cudaGetLastError(), "statisticsCollectionKernel launch");
    checkCudaError(cudaDeviceSynchronize(), "statisticsCollectionKernel synchronization");

    printf("All kernels launched and completed successfully.\n");

    // Free device memory
    printf("Freeing GPU memory...\n");
    cudaFree(d_agents.x);
    cudaFree(d_agents.y);
    cudaFree(d_agents.homeX);
    cudaFree(d_agents.homeY);
    cudaFree(d_agents.vx);
    cudaFree(d_agents.vy);
    cudaFree(d_agents.state);
    cudaFree(d_agents.stateTimer);
    cudaFree(d_agents.cellId);
    cudaFree(d_agents.rngStates);
    printf("GPU memory freed.\n");

    // Free dynamically allocated memory in config
    free_simulation_config(&h_config);

    return 0;
}
