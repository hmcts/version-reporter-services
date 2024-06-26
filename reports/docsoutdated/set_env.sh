#!/bin/bash

# Get the vault name from the environment variable
secret_path=${SECRET_PATH:-/mnt/secrets}
vault_name=${VAULT_NAME:-vault}

echo "path supplied: $secret_path"
echo "vault name supplied: $vault_name"

# Construct the directory path
directory_path="$secret_path/$vault_name"

echo "Creating environment variables..."
# Check if the directory exists
if [ -d "$directory_path" ]; then
    # Iterate over all files in the directory
    for filename in $(ls $directory_path); do
        # Construct the full file path
        file_path="$directory_path/$filename"
        
        # Check if the file exists and is a file
        if [ -f "$file_path" ]; then
            # Read the file content
            content=$(cat $file_path)
            
            # Export the environment variable
            export $filename=$content
        else
            echo "**********************************"
            echo "Warning: $file_path is not a file."
            echo "**********************************"
            echo
        fi
    done
else
    echo "****************************************"
    echo "Warning: $directory_path does not exist."
    echo "****************************************"
    echo
fi