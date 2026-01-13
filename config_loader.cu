#include "config_loader.h"
#include "third_party/cJSON.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void load_simulation_config(const char *filename, SimulationConfig *config) {

    FILE *f = fopen(filename, "rb");
    if (f == NULL) {
        fprintf(stderr, "Error: Cannot open config file %s\n", filename);
        exit(1);
    }
    fseek(f, 0, SEEK_END);
    long length = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buffer = (char *)malloc(length + 1);
    size_t bytes_read = fread(buffer, 1, length, f);
    if (bytes_read != length) {
        fprintf(stderr,
                "Error: Could not read full config file %s. Expected %ld bytes, read %zu bytes.\n",
                filename, length, bytes_read);
        fclose(f);
        free(buffer);
        exit(1);
    }
    fclose(f);
    buffer[length] = '\0';

    cJSON *json = cJSON_Parse(buffer);
    if (json == NULL) {
        const char *error_ptr = cJSON_GetErrorPtr();
        if (error_ptr != NULL) {
            fprintf(stderr, "Error before: %s\n", error_ptr);
        }
        exit(1);
    }

    cJSON *sim = cJSON_GetObjectItem(json, "simulation");
    config->simulation.num_agents = cJSON_GetObjectItem(sim, "num_agents")->valueint;
    cJSON *world_size = cJSON_GetObjectItem(sim, "world_size");
    config->simulation.world_size[0] = (float)cJSON_GetArrayItem(world_size, 0)->valuedouble;
    config->simulation.world_size[1] = (float)cJSON_GetArrayItem(world_size, 1)->valuedouble;
    config->simulation.timestep = (float)cJSON_GetObjectItem(sim, "timestep")->valuedouble;
    config->simulation.duration = cJSON_GetObjectItem(sim, "duration")->valueint;
    config->simulation.randomSeed = cJSON_GetObjectItem(sim, "randomSeed")->valueint;

    cJSON *disease = cJSON_GetObjectItem(json, "disease");
    // Error check
    if (!cJSON_IsObject(disease)) {
        fprintf(stderr, "Error: 'disease' object not found or invalid in config file.\n");
        exit(1);
    }
    cJSON *inc_period = cJSON_GetObjectItem(disease, "incubation_period");
    // Error check
    if (!cJSON_IsObject(inc_period)) {
        fprintf(stderr, "Error: 'incubation_period' object not found or invalid.\n");
        exit(1);
    }
    config->disease.incubation_period.mean = cJSON_GetObjectItem(inc_period, "mean")->valuedouble;
    config->disease.incubation_period.std = cJSON_GetObjectItem(inc_period, "std")->valuedouble;
    cJSON *inf_period = cJSON_GetObjectItem(disease, "infectious_period");
    // Error check
    if (!cJSON_IsObject(inf_period)) {
        fprintf(stderr, "Error: 'infectious_period' object not found or invalid.\n");
        exit(1);
    }
    config->disease.infectious_period.mean = cJSON_GetObjectItem(inf_period, "mean")->valuedouble;
    config->disease.infectious_period.std = cJSON_GetObjectItem(inf_period, "std")->valuedouble;
    config->disease.transmission_probability =
        (float)cJSON_GetObjectItem(disease, "transmission_probability")->valuedouble;
    config->disease.contact_radius =
        (float)cJSON_GetObjectItem(disease, "contact_radius")->valuedouble;
    config->disease.initial_infected = cJSON_GetObjectItem(disease, "initial_infected")->valueint;

    cJSON *agent_behavior_json = cJSON_GetObjectItem(json, "agent_behavior");
    if (!cJSON_IsObject(agent_behavior_json)) {
        fprintf(stderr, "Error: 'agent_behavior' object not found or invalid in config file.\n");
        exit(1);
    }
    config->agent_behavior.movement_speed =
        (float)cJSON_GetObjectItem(agent_behavior_json, "movement_speed")->valuedouble;
    config->agent_behavior.mobility_radius =
        (float)cJSON_GetObjectItem(agent_behavior_json, "mobility_radius")->valuedouble;
    config->agent_behavior.home_return_probability =
        (float)cJSON_GetObjectItem(agent_behavior_json, "home_return_probability")->valuedouble;

    // Initialize intervention pointers to NULL
    config->lockdown = NULL;
    config->vaccination = NULL;

    cJSON *interventions_json = cJSON_GetObjectItem(json, "interventions");
    if (cJSON_IsArray(interventions_json)) {
        int num_interventions = cJSON_GetArraySize(interventions_json);
        for (int i = 0; i < num_interventions; i++) {
            cJSON *intervention_json = cJSON_GetArrayItem(interventions_json, i);
            cJSON *type_json = cJSON_GetObjectItem(intervention_json, "type");
            if (cJSON_IsString(type_json)) {
                if (strcmp(type_json->valuestring, "lockdown") == 0) {
                    config->lockdown = (InterventionLockdown *)malloc(sizeof(InterventionLockdown));
                    config->lockdown->start_day =
                        cJSON_GetObjectItem(intervention_json, "start_day")->valueint;
                    config->lockdown->end_day =
                        cJSON_GetObjectItem(intervention_json, "end_day")->valueint;
                    config->lockdown->mobility_reduction = (float)cJSON_GetObjectItem(
                        intervention_json, "mobility_reduction")->valuedouble;
                } else if (strcmp(type_json->valuestring, "vaccination") == 0) {
                    config->vaccination =
                        (InterventionVaccination *)malloc(sizeof(InterventionVaccination));
                    config->vaccination->start_day =
                        cJSON_GetObjectItem(intervention_json, "start_day")->valueint;
                    config->vaccination->daily_capacity =
                        cJSON_GetObjectItem(intervention_json, "daily_capacity")->valueint;
                    config->vaccination->efficacy =
                        (float)cJSON_GetObjectItem(intervention_json, "efficacy")->valuedouble;
                }
            }
        }
    }

    printf("Config loaded successfully.\n");
    printf("Number of agents: %d\n", config->simulation.num_agents);
    printf("World size: %f x %f\n", config->simulation.world_size[0],
           config->simulation.world_size[1]);

    printf("Agent Behavior:\n");
    printf("  Movement Speed: %f\n", config->agent_behavior.movement_speed);
    printf("  Mobility Radius: %f\n", config->agent_behavior.mobility_radius);
    printf("  Home Return Probability: %f\n", config->agent_behavior.home_return_probability);

    if (config->lockdown) {
        printf("Lockdown Intervention:\n");
        printf("  Start Day: %d\n", config->lockdown->start_day);
        printf("  End Day: %d\n", config->lockdown->end_day);
        printf("  Mobility Reduction: %f\n", config->lockdown->mobility_reduction);
    }

    if (config->vaccination) {
        printf("Vaccination Intervention:\n");
        printf("  Start Day: %d\n", config->vaccination->start_day);
        printf("  Daily Capacity: %d\n", config->vaccination->daily_capacity);
        printf("  Efficacy: %f\n", config->vaccination->efficacy);
    }

    cJSON_Delete(json);
    free(buffer);
}

void free_simulation_config(SimulationConfig *config) {
    if (config == NULL) {
        return;
    }

    if (config->lockdown != NULL) {
        free(config->lockdown);
        config->lockdown = NULL;
    }

    if (config->vaccination != NULL) {
        free(config->vaccination);
        config->vaccination = NULL;
    }
}