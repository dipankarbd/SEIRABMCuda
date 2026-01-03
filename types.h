#ifndef TYPES_H
#define TYPES_H

#include "cJSON.h"
#include <curand_kernel.h>
#include <stdbool.h>

enum SEIRState { SUSCEPTIBLE = 0, EXPOSED = 1, INFECTIOUS = 2, RECOVERED = 3 };

typedef struct {
    float *x;               // x positions
    float *y;               // y positions
    float *homeX;           // home x positions
    float *homeY;           // home y positions
    float *vx;              // velocity x
    float *vy;              // velocity y
    unsigned int *state;    // SEIR state
    float *stateTimer;      // time remaining in current state
    unsigned int *cellId;   // spatial hash
    curandState *rngStates; // RNG state per agent
} AgentData;

typedef struct {
    int susceptible;
    int exposed;
    int infectious;
    int recovered;
} Statistics;

typedef struct {
    double mean;
    double std;
} TimeDistribution;

typedef struct {
    int num_agents;
    float world_size[2];
    float timestep;
    int duration;
    int randomSeed;
} SimulationParams;

typedef struct {
    TimeDistribution incubation_period;
    TimeDistribution infectious_period;
    float transmission_probability;
    float contact_radius;
    int initial_infected;
} DiseaseParams;

typedef struct {
    float movement_speed;
    float mobility_radius;
    float home_return_probability;
} AgentBehavior;

typedef struct {
    int snapshotInterval;
    char *outputDir;
    bool saveAnimationFrames;
    int animationFrameInterval;
} OutputParams;

typedef struct {
    SimulationParams simulation;
    DiseaseParams disease;
    AgentBehavior agent_behavior;
    OutputParams output;
} SimulationConfig;

#endif
