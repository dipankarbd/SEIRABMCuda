#include "config_loader.h"
#include "kernel.h"
#include "support.h"
#include "types.h"
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>

void allocateAgentData(AgentData *d_agents, int num_agents) {
    printf("Allocating memory for %d agents on GPU...\n", num_agents);

    cudaError_t cudaStat;
    cudaStat = cudaMalloc((void **)&d_agents->x, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.x");
    cudaStat = cudaMalloc((void **)&d_agents->y, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.y");
    cudaStat = cudaMalloc((void **)&d_agents->homeX, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.homeX");
    cudaStat = cudaMalloc((void **)&d_agents->homeY, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.homeY");
    cudaStat = cudaMalloc((void **)&d_agents->vx, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.vx");
    cudaStat = cudaMalloc((void **)&d_agents->vy, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.vy");
    cudaStat = cudaMalloc((void **)&d_agents->state, num_agents * sizeof(uint8_t));
    checkCudaError(cudaStat, "cudaMalloc d_agents.state");
    cudaStat = cudaMalloc((void **)&d_agents->stateTimer, num_agents * sizeof(float));
    checkCudaError(cudaStat, "cudaMalloc d_agents.stateTimer");
    cudaStat = cudaMalloc((void **)&d_agents->cellId, num_agents * sizeof(unsigned int));
    checkCudaError(cudaStat, "cudaMalloc d_agents.cellId");
    cudaStat = cudaMalloc((void **)&d_agents->rngStates, num_agents * sizeof(curandState));
    checkCudaError(cudaStat, "cudaMalloc d_agents.rngStates");

    printf("Memory allocation successful.\n");
}

void freeAgentData(AgentData *d_agents) {
    printf("Freeing GPU memory...\n");
    cudaFree(d_agents->x);
    cudaFree(d_agents->y);
    cudaFree(d_agents->homeX);
    cudaFree(d_agents->homeY);
    cudaFree(d_agents->vx);
    cudaFree(d_agents->vy);
    cudaFree(d_agents->state);
    cudaFree(d_agents->stateTimer);
    cudaFree(d_agents->cellId);
    cudaFree(d_agents->rngStates);
    printf("GPU memory freed.\n");
}

int main(int argc, char *argv[]) {
    printf("\nGPU-Accelerated Agent-Based SEIR Epidemic Simulation...\n");

    SimulationConfig h_config;
    load_simulation_config("config.json", &h_config);

    AgentData d_agents;

    int num_agents = h_config.simulation.num_agents;
    int random_seed = h_config.simulation.randomSeed;
    float world_width = h_config.simulation.world_size[0];
    float world_height = h_config.simulation.world_size[1];
    float agent_movement_speed = h_config.agent_behavior.movement_speed;
    float home_return_probability = h_config.agent_behavior.home_return_probability;
    float timestep = h_config.simulation.timestep;

    float cell_size = h_config.disease.contact_radius * 2.0f;
    int grid_width = (int)ceilf(world_width / cell_size);
    int grid_height = (int)ceilf(world_height / cell_size);

    float infectious_mean = h_config.disease.infectious_period.mean;
    float infectious_std = h_config.disease.infectious_period.std;

    float contact_radius = h_config.disease.contact_radius;
    float incubation_mean = (float)h_config.disease.incubation_period.mean;
    float incubation_std = (float)h_config.disease.incubation_period.std;
    float transmission_prob = h_config.disease.transmission_probability;

    allocateAgentData(&d_agents, num_agents);

    // Determine grid and block dimensions
    int threadsPerBlock = 256;
    int numBlocks = (num_agents + threadsPerBlock - 1) / threadsPerBlock;

    printf("Launching agentInitializationKernel...\n");
    agentInitializationKernel<<<numBlocks, threadsPerBlock>>>(
        d_agents, num_agents, random_seed, world_width, world_height, agent_movement_speed);
    checkCudaError(cudaGetLastError(), "agentInitializationKernel launch");
    checkCudaError(cudaDeviceSynchronize(), "agentInitializationKernel synchronization");

    // TODO - infect initial agents

    printf("Launching agentMovementKernel...\n");
    agentMovementKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents, world_width,
                                                        world_height, agent_movement_speed,
                                                        home_return_probability, timestep);
    checkCudaError(cudaGetLastError(), "agentMovementKernel launch");

    printf("Launching spatialIndexingKernel...\n");
    spatialIndexingKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents, cell_size,
                                                          grid_width);
    checkCudaError(cudaGetLastError(), "spatialIndexingKernel launch");

    printf("Launching diseaseTransmissionKernel...\n");
    diseaseTransmissionKernel<<<numBlocks, threadsPerBlock>>>(
        d_agents, num_agents, grid_width, grid_height, contact_radius, incubation_mean,
        incubation_std, transmission_prob);
    checkCudaError(cudaGetLastError(), "diseaseTransmissionKernel launch");

    printf("Launching stateTransitionKernel...\n");
    stateTransitionKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents, timestep,
                                                          infectious_mean, infectious_std);
    checkCudaError(cudaGetLastError(), "stateTransitionKernel launch");

    printf("Launching statisticsCollectionKernel...\n");
    statisticsCollectionKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents);
    checkCudaError(cudaGetLastError(), "statisticsCollectionKernel launch");
    checkCudaError(cudaDeviceSynchronize(), "statisticsCollectionKernel synchronization");

    printf("All kernels launched and completed successfully.\n");

    freeAgentData(&d_agents);

    // Free dynamically allocated memory in config
    free_simulation_config(&h_config);

    return 0;
}