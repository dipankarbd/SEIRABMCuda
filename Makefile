NVCC        = nvcc
NVCC_FLAGS  = -O3 -Iinclude -Ithird_party -Ikernels -I.
LD_FLAGS    = -lcudart -lm
EXE	        = seirabmcuda

OBJ_DIR     = obj_tmp

# Source files
SRCS_CU     = main.cu config_loader.cu
SRCS_C      = third_party/cJSON.c
SRCS_KERNELS= kernels/agent_initialization.cu kernels/agent_movement.cu \
              kernels/spatial_indexing.cu kernels/disease_transmission.cu \
              kernels/state_transition.cu kernels/statistics_collection.cu

# Object files paths (prepending OBJ_DIR)
OBJS_CU     = $(patsubst %.cu,$(OBJ_DIR)/%.o,$(SRCS_CU))
OBJS_C      = $(patsubst third_party/%.c,$(OBJ_DIR)/third_party/%.o,$(SRCS_C))
OBJS_KERNELS= $(patsubst kernels/%.cu,$(OBJ_DIR)/kernels/%.o,$(SRCS_KERNELS))

OBJ	        = $(OBJS_CU) $(OBJS_C) $(OBJS_KERNELS)

default: $(EXE)

# Create object directory and subdirectories
$(OBJ_DIR):
	mkdir -p $(OBJ_DIR) $(OBJ_DIR)/third_party $(OBJ_DIR)/kernels

# Generic compilation rules
$(OBJ_DIR)/%.o: %.cu | $(OBJ_DIR)
	$(NVCC) $(NVCC_FLAGS) -c $< -o $@

$(OBJ_DIR)/third_party/%.o: third_party/%.c | $(OBJ_DIR)
	$(NVCC) $(NVCC_FLAGS) -c $< -o $@

$(OBJ_DIR)/kernels/%.o: kernels/%.cu | $(OBJ_DIR)
	$(NVCC) $(NVCC_FLAGS) -c $< -o $@

# Header dependencies
$(OBJ_DIR)/main.o: main.cu config_loader.h types.h
$(OBJ_DIR)/config_loader.o: config_loader.cu config_loader.h types.h
$(OBJ_DIR)/third_party/cJSON.o: third_party/cJSON.c third_party/cJSON.h
$(OBJ_DIR)/kernels/agent_initialization.o: kernels/agent_initialization.cu kernels/kernel.h
$(OBJ_DIR)/kernels/agent_movement.o: kernels/agent_movement.cu kernels/kernel.h
$(OBJ_DIR)/kernels/spatial_indexing.o: kernels/spatial_indexing.cu kernels/kernel.h
$(OBJ_DIR)/kernels/disease_transmission.o: kernels/disease_transmission.cu kernels/kernel.h
$(OBJ_DIR)/kernels/state_transition.o: kernels/state_transition.cu kernels/kernel.h
$(OBJ_DIR)/kernels/statistics_collection.o: kernels/statistics_collection.cu kernels/kernel.h

$(EXE): $(OBJ)
	$(NVCC) $(OBJ) -o $(EXE) $(LD_FLAGS)

# Clean generated files
clean:
	rm -rf $(OBJ_DIR) $(EXE)