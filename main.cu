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
    cudaStat = cudaMalloc((void **)&d_agents->state, num_agents * sizeof(unsigned int));
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

void infectInitialAgents(AgentData d_agents, int num_agents, int initial_infected, int random_seed,
                         float infectious_mean) {
    if (initial_infected <= 0 || initial_infected > num_agents) {
        return;
    }

    printf("Infecting %d agents...\n", initial_infected);

    unsigned int *h_agents_state = (unsigned int *)malloc(num_agents * sizeof(unsigned int));
    float *h_agents_stateTimer = (float *)malloc(num_agents * sizeof(float));

    cudaMemcpy(h_agents_state, d_agents.state, num_agents * sizeof(unsigned int),
               cudaMemcpyDeviceToHost);
    cudaMemcpy(h_agents_stateTimer, d_agents.stateTimer, num_agents * sizeof(float),
               cudaMemcpyDeviceToHost);

    srand(random_seed);
    for (int i = 0; i < initial_infected; i++) {
        int idx = rand() % num_agents;
        h_agents_state[idx] = INFECTIOUS;
        h_agents_stateTimer[idx] = infectious_mean;
    }

    cudaMemcpy(d_agents.state, h_agents_state, num_agents * sizeof(unsigned int),
               cudaMemcpyHostToDevice);
    cudaMemcpy(d_agents.stateTimer, h_agents_stateTimer, num_agents * sizeof(float),
               cudaMemcpyHostToDevice);

    free(h_agents_state);
    free(h_agents_stateTimer);
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

    int threadsPerBlock = BLOCK_SIZE;
    int numBlocks = (num_agents + threadsPerBlock - 1) / threadsPerBlock;

    printf("Initializing agents...\n");
    agentInitializationKernel<<<numBlocks, threadsPerBlock>>>(
        d_agents, num_agents, random_seed, world_width, world_height, agent_movement_speed);
    checkCudaError(cudaGetLastError(), "agentInitializationKernel launch");
    checkCudaError(cudaDeviceSynchronize(), "agentInitializationKernel synchronization");

    infectInitialAgents(d_agents, num_agents, h_config.disease.initial_infected, random_seed,
                        infectious_mean);

    int totalSteps = (int)(h_config.simulation.duration / h_config.simulation.timestep);

    Statistics *h_stats = (Statistics *)malloc(totalSteps * sizeof(Statistics));
    memset(h_stats, 0, totalSteps * sizeof(Statistics));

    Statistics *d_stat;
    cudaMalloc((void **)&d_stat, sizeof(Statistics));

    printf("Running simulation loop...\n");
    for (int step = 0; step < totalSteps; step++) {
        float currentDay = step * timestep;

        agentMovementKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents, world_width,
                                                            world_height, agent_movement_speed,
                                                            home_return_probability, timestep);
        checkCudaError(cudaGetLastError(), "agentMovementKernel launch");

        spatialIndexingKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents, cell_size,
                                                              grid_width);
        checkCudaError(cudaGetLastError(), "spatialIndexingKernel launch");

        diseaseTransmissionKernel<<<numBlocks, threadsPerBlock>>>(
            d_agents, num_agents, grid_width, grid_height, contact_radius, incubation_mean,
            incubation_std, transmission_prob);
        checkCudaError(cudaGetLastError(), "diseaseTransmissionKernel launch");

        stateTransitionKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents, timestep,
                                                              infectious_mean, infectious_std);
        checkCudaError(cudaGetLastError(), "stateTransitionKernel launch");

        cudaMemset(d_stat, 0, sizeof(Statistics));

        statisticsCollectionKernel<<<numBlocks, threadsPerBlock>>>(d_agents, num_agents, d_stat);
        checkCudaError(cudaGetLastError(), "statisticsCollectionKernel launch");
        checkCudaError(cudaDeviceSynchronize(), "statisticsCollectionKernel synchronization");

        cudaMemcpy(&h_stats[step], d_stat, sizeof(Statistics), cudaMemcpyDeviceToHost);

        printf("Day %.1f: S=%d E=%d I=%d R=%d\n", currentDay, h_stats[step].susceptible,
               h_stats[step].exposed, h_stats[step].infectious, h_stats[step].recovered);
    }

    cudaFree(d_stat);
    freeAgentData(&d_agents);
    free(h_stats);
    free_simulation_config(&h_config);

    return 0;
}