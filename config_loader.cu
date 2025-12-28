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

    cJSON *output_json = cJSON_GetObjectItem(json, "output");
    if (!cJSON_IsObject(output_json)) {
        fprintf(stderr, "Error: 'output' object not found or invalid in config file.\n");
        exit(1);
    }
    cJSON *snapshot_interval_json = cJSON_GetObjectItem(output_json, "snapshotInterval");
    if (cJSON_IsNumber(snapshot_interval_json)) {
        config->output.snapshotInterval = snapshot_interval_json->valueint;
    } else {
        fprintf(stderr,
                "Error: 'snapshotInterval' not found or invalid in output configuration.\n");
        exit(1);
    }
    cJSON *output_dir_json = cJSON_GetObjectItem(output_json, "outputDir");
    if (cJSON_IsString(output_dir_json)) {
        config->output.outputDir = strdup(output_dir_json->valuestring);
    } else {
        fprintf(stderr, "Error: 'outputDir' not found or invalid in output configuration.\n");
        exit(1);
    }
    cJSON *save_animation_frames_json = cJSON_GetObjectItem(output_json, "saveAnimationFrames");
    if (cJSON_IsBool(save_animation_frames_json)) {
        config->output.saveAnimationFrames = cJSON_IsTrue(save_animation_frames_json);
    } else {
        fprintf(stderr,
                "Error: 'saveAnimationFrames' not found or invalid in output configuration.\n");
        exit(1);
    }
    cJSON *animation_frame_interval_json =
        cJSON_GetObjectItem(output_json, "animationFrameInterval");
    if (cJSON_IsNumber(animation_frame_interval_json)) {
        config->output.animationFrameInterval = animation_frame_interval_json->valueint;
    } else {
        fprintf(stderr,
                "Error: 'animationFrameInterval' not found or invalid in output configuration.\n");
        exit(1);
    }

    printf("Config loaded successfully.\n");
    printf("Number of agents: %d\n", config->simulation.num_agents);
    printf("World size: %f x %f\n", config->simulation.world_size[0],
           config->simulation.world_size[1]);

    printf("Agent Behavior:\n");
    printf("  Movement Speed: %f\n", config->agent_behavior.movement_speed);
    printf("  Mobility Radius: %f\n", config->agent_behavior.mobility_radius);
    printf("  Home Return Probability: %f\n", config->agent_behavior.home_return_probability);

    printf("Output Parameters:\n");
    printf("  Snapshot Interval: %d\n", config->output.snapshotInterval);
    printf("  Output Directory: %s\n", config->output.outputDir);
    printf("  Save Animation Frames: %s\n", config->output.saveAnimationFrames ? "true" : "false");
    printf("  Animation Frame Interval: %d\n", config->output.animationFrameInterval);

    cJSON_Delete(json);
    free(buffer);
}

void free_simulation_config(SimulationConfig *config) {
    if (config == NULL) {
        return;
    }

    if (config->output.outputDir != NULL) {
        free(config->output.outputDir);
        config->output.outputDir = NULL;
    }
}