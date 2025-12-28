#ifndef CONFIG_LOADER_H
#define CONFIG_LOADER_H

#include "types.h"

#ifdef __cplusplus
extern "C" {
#endif

void load_simulation_config(const char *filename, SimulationConfig *config);
void free_simulation_config(SimulationConfig *config);

#ifdef __cplusplus
}
#endif

#endif