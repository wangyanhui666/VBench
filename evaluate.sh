#!/bin/bash

# Define the model list
model_paths=("full_attention/0528_full_attention_flowmaching_guide_scale6_shift3.0" "sparse_attention_STA/0530_SAwindow222_flowmaching_guide_scale6_shift3.0" "sparse_attention_ours/0530_SAwindow222_flowmaching_guide_scale6_shift3.0")

# Define the dimension list
dimensions=("subject_consistency" "background_consistency" "aesthetic_quality" "imaging_quality" "object_class" "multiple_objects" "color" "spatial_relationship" "scene" "temporal_style" "overall_consistency" "human_action" "temporal_flickering" "motion_smoothness" "dynamic_degree" "appearance_style")

# Base path for videos
base_path='/mnt/shangcephfs/wangyanhui/distillation/VBench/' # TODO: change to local path

# Check if base_path exists
if [ ! -d "$base_path" ]; then
    echo "Error: Base path '$base_path' does not exist or is not a directory."
    exit 1
fi

echo "Starting script..."
echo "Models to process: ${model_paths[@]}"
echo "Dimensions to process: ${dimensions[@]}"
echo "----------------------------------------"

# Loop over each model
for model in "${model_paths[@]}"; do
    echo "Processing Model: $model"
    
    # Define the main output directory for the current model
    model_output_base_dir="${base_path}${model}/output/"
    # Ensure this base output directory for the model exists
    mkdir -p "$model_output_base_dir"
    if [ $? -ne 0 ]; then
        echo "    Error: Could not create base output directory '$model_output_base_dir' for model '$model'. Skipping model."
        echo "----------------------------------------"
        continue # Skip to the next model
    fi

    # Loop over each dimension
    for i in "${!dimensions[@]}"; do
        dimension=${dimensions[i]}

        # Construct paths
        videos_path="${base_path}${model}/video"
        # This is where evaluate.py will save its specific results for the dimension
        dimension_specific_output_path="${model_output_base_dir}${dimension}" 
        # This is the log file for the torchrun command itself for this dimension
        log_file="${model_output_base_dir}${dimension}_execution.log"

        echo "  Dimension: $dimension"
        echo "    Videos Path: $videos_path"
        echo "    Dimension Output Path (for evaluate.py): $dimension_specific_output_path"
        echo "    Log file for torchrun: $log_file"

        # Check if videos_path exists
        if [ ! -d "$videos_path" ]; then
            echo "    Warning: Videos path '$videos_path' does not exist for model '$model'. Skipping torchrun for this dimension." >&2 # Send warning to stderr
            echo "Skipping ${dimension} for ${model} due to missing videos_path." >> "$log_file" # Also log it
            echo "  ----------------------------------------"
            continue # Skip to the next dimension
        fi

        # Create dimension-specific output directory for evaluate.py
        mkdir -p "$dimension_specific_output_path"
        if [ $? -ne 0 ]; then
            echo "    Error: Could not create dimension-specific output directory '$dimension_specific_output_path'. Skipping torchrun for this dimension." >&2
            echo "Error creating output directory ${dimension_specific_output_path}." >> "$log_file"
            echo "  ----------------------------------------"
            continue
        fi

        echo "    Executing: torchrun --nproc_per_node=8 --standalone evaluate.py --videos_path \"$videos_path\" --dimension \"$dimension\" --output_path \"$dimension_specific_output_path\""
        # Run the evaluation script and redirect its stdout and stderr to the log file
        torchrun --nproc_per_node=8 --standalone evaluate.py --videos_path "$videos_path" --dimension "$dimension" --output_path "$dimension_specific_output_path" > "$log_file" 2>&1
        
        # Optional: Check exit status of torchrun
        if [ $? -ne 0 ]; then
            echo "    Error: torchrun failed for dimension '$dimension' and model '$model'. Check log: $log_file" >&2
        else
            echo "    Successfully executed torchrun for dimension '$dimension'. Log: $log_file"
        fi
        echo "  ----------------------------------------"
    done
    echo "----------------------------------------"
done

echo "Script finished."