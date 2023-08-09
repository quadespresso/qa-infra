#!/bin/bash

FILE="/var/log/.cloud_init_done"

# Define the loop function command string
CMD=$(cat <<EOF
until [[ -e "${FILE}" ]]; do
    echo "Waiting for cloud-init to finish..."
    sleep 3
  done
echo "Found ${FILE} - cloud-init is finished."
EOF
)

# Set the timeout duration in seconds (30 minutes = 30 minutes * 60 seconds)
TIME_LIMIT=$((30 * 60))

# Call the function using timeout
timeout "${TIME_LIMIT}" bash -c "${CMD}"

# Check if the loop terminated due to a timeout or if the file was found
if [[ $? -eq 124 ]]; then
    echo "Timeout reached after ${TIME_LIMIT} minutes."
    exit 1
fi
