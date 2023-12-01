#!/bin/bash

POD_PER_NODE_MIN=20
POD_PER_NODE_MAX=650
POD_PER_NODE_LIMIT_DEFAULT=110
PODS_PER_NODE_LIMIT=$POD_PER_NODE_LIMIT_DEFAULT
MKE_USER_DEFAULT='admin'
MKE_USER=$MKE_USER_DEFAULT
MKE_CONFIG_TOML_PATH_DEFAULT=/tmp/mke-config.toml
MKE_CONFIG_TOML_PATH=$MKE_CONFIG_TOML_PATH_DEFAULT

# Function to display script usage
show_usage() {
    cat <<EOF

Updates the pods per node limit in an MKE cluster

Usage:
  $0 [options]

Options:
  -h, --help                  Display this help message
  -v, --view                  Display pods-per-node limit but do NOT update the value
  -p, --pods-per-node-limit   Specify the number of pods per node (default is $PODS_PER_NODE_LIMIT_DEFAULT)
  --mke-host                  MKE Manager host name (or LB name)
  --mke-user                  MKE admin user (default is $MKE_USER_DEFAULT)
  --mke-password              MKE user password
  --mke-config-toml-path      Specify where the config.toml file should be output (default is $MKE_CONFIG_TOML_PATH_DEFAULT)

Links:
  - Based on:
    https://github.com/Mirantis/orca/blob/master/perf/setPodsPerNodeLimit.sh

EOF
}

# MKE Auth Token Function
get_mke_auth_token() {
    local MKE_USER="$1"
    local MKE_PASSWORD="$2"
    local MKE_HOST="$3"

    echo "Obtaining an auth token from MKE..." >&2
    
    local AUTHTOKEN
    AUTHTOKEN=$(curl -sk -d "{\"username\":\"$MKE_USER\",\"password\":\"$MKE_PASSWORD\"}" "https://$MKE_HOST/auth/login" | grep -oP '(?<="auth_token":")[^"]*')
    
    if [ -z "$AUTHTOKEN" ]; then
        echo "Error: Unable to obtain auth token from MKE." >&2
        return 1
    fi
    
    echo "Obtaining an auth token from MKE complete." >&2   
    echo "$AUTHTOKEN"
}

# MKE config TOML download
download_mke_config_toml() {
    local MKE_HOST="$1"
    local AUTHTOKEN="$2"
    local TOML_FILE_PATH="$3"

    echo "Downloading MKE configuration file to [$TOML_FILE_PATH]..." >&2

    local CONFIG_RESPONSE
    CONFIG_RESPONSE=$(curl --silent --insecure -X GET "https://$MKE_HOST/api/ucp/config-toml" -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN")

    if [ $? -ne 0 ]; then
        echo "Error: Unable to download MKE configuration file." >&2
        return 1
    fi

    if [ -z "$CONFIG_RESPONSE" ]; then
        echo "Error: MKE configuration file is empty." >&2
        return 1
    fi

    echo "$CONFIG_RESPONSE" > "$TOML_FILE_PATH"
    echo "Downloading MKE configuration file complete." >&2
}

# MKE config TOML upload
upload_mke_config_toml() {
    local MKE_HOST="$1"
    local AUTHTOKEN="$2"
    local TOML_FILE_PATH="$3"

    if [ ! -e "$TOML_FILE_PATH" ]; then
        echo "Error: TOML file does not exist at [$TOML_FILE_PATH]." >&2
        return 1
    fi

    echo "Uploading MKE configuration file [$TOML_FILE_PATH]..." >&2
    curl --silent --insecure -X PUT "https://$MKE_HOST/api/ucp/config-toml" -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN" --upload-file "$TOML_FILE_PATH"
    if [ $? -ne 0 ]; then
        echo "Error: Unable to upload MKE configuration file." >&2
        return 1
    fi
    echo "Uploading MKE configuration file complete." >&2
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mke-host)
            if [ -z "$2" ]; then
                printf "Error: The MKE host must be specified after --mke-host.\n"
                exit 1
            fi
            MKE_HOST="$2"
            shift 2
            ;;
        --mke-user)
            if [ -z "$2" ]; then
                printf "Error: The MKE user must be specified after --mke-user.\n"
                exit 1
            fi
            MKE_USER="$2"
            shift 2
            ;;
        --mke-password)
            if [ -z "$2" ]; then
                printf "Error: The MKE password must be specified after --mke-password.\n"
                exit 1
            fi
            MKE_PASSWORD="$2"
            shift 2
            ;;
        --mke-config-toml-path)
            if [ -z "$2" ]; then
                printf "Error: The config TOML path must be specified after --mke-config-toml-path.\n"
                exit 1
            fi
            MKE_CONFIG_TOML_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -p|--pods-per-node-limit)
            if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                printf "Error: The pod per node limit must be a valid integer after --pods-per-node-limit.\n"
                exit 1
            fi
            if (( $2 < $POD_PER_NODE_MIN || $2 > $POD_PER_NODE_MAX )); then
                printf "Error: The pod per node limit must be between $POD_PER_NODE_MIN and $POD_PER_NODE_MAX.\n"
                exit 1
            fi
            PODS_PER_NODE_LIMIT="$2"
            shift 2
            ;;
        -v|--view)
            VIEW_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$MKE_HOST" ]; then
  read -p "Enter MKE manager host name: " MKE_HOST
fi

if [ -z "$MKE_PASSWORD" ]; then
  read -s -p "Enter MKE password for user [$MKE_USER]: " MKE_PASSWORD
fi

AUTHTOKEN=$(get_mke_auth_token "$MKE_USER" "$MKE_PASSWORD" "$MKE_HOST")
if [ $? -ne 0 ]; then
    exit 1
fi
download_mke_config_toml "$MKE_HOST" "$AUTHTOKEN" "$MKE_CONFIG_TOML_PATH"
if [ $? -ne 0 ]; then
    exit 1
fi

PODS_PER_NODE_LIMIT_SETTING=$(grep -Po 'kubelet_max_pods = \K\d+' "$MKE_CONFIG_TOML_PATH" | awk '{print $1}')
printf "Current MKE pods-per-node limit is [$PODS_PER_NODE_LIMIT_SETTING].\n"
if [ "$VIEW_ONLY" = true ]; then       
    exit 0
fi
if [ "$PODS_PER_NODE_LIMIT_SETTING" -eq "$PODS_PER_NODE_LIMIT" ]; then
    printf "The MKE pods-per-node limit already matches the desired value - no update performed.\n"
    exit 0
fi
printf "Updating MKE pods-per-node limit from [$PODS_PER_NODE_LIMIT_SETTING] to [$PODS_PER_NODE_LIMIT]...\n"
sed -i -e "/kubelet_max_pods =/ s/= .*/= $PODS_PER_NODE_LIMIT/" $MKE_CONFIG_TOML_PATH
upload_mke_config_toml "$MKE_HOST" "$AUTHTOKEN" "$MKE_CONFIG_TOML_PATH"
if [ $? -ne 0 ]; then
    exit 1
fi
printf "Updating MKE pods-per-node limit complete.\n"