#!/bin/bash

REPORT_DIR_DEFAULT="./reports"
REPORT_DIR=$REPORT_DIR_DEFAULT
USER_COUNT_DEFAULT=20
USER_COUNT=$USER_COUNT_DEFAULT
USER_COUNT_MIN=1
USER_COUNT_MAX=1000
USER_COUNT_VALUES=("$USER_COUNT_DEFAULT")
POD_PER_NODE_LIMIT_DEFAULT=110
PODS_PER_NODE_DEFAULT=100
PODS_PER_NODE=$PODS_PER_NODE_DEFAULT
MKE_USER_DEFAULT='admin'
MKE_USER=$MKE_USER_DEFAULT
MKE_CONFIG_TOML_PATH_DEFAULT=/tmp/mke-config.toml
MKE_CONFIG_TOML_PATH=$MKE_CONFIG_TOML_PATH_DEFAULT

# Function to display script usage
show_usage() {
    cat <<EOF

Performs a load (creates k8s resources + makes API requests) test against an MKE cluster

Usage:
  $0 [options]

Options:
  -h, --help                  Display this help message
  -l, --load                  Specify a value representing a pre-defined cluster load (k8s resources)
  -u, --user-num              Number of users (default is $USER_COUNT_DEFAULT) in simulated load. If a list of numbers
                              (for ex. 25 50 100) is provided the script will perform separate API test
                              runs for each batch of users
  -p, --pods-per-node         Specify the number of pods per node (default is $PODS_PER_NODE_DEFAULT)
  --mke-url                   URL to MKE (will be prompted if not supplied)
  --mke-user                  MKE admin user (default is $MKE_USER_DEFAULT)
  --mke-password              MKE user password (will be prompted if not supplied)
  --mke-config-toml-path      Specify where the config.toml file should be output (default is $MKE_CONFIG_TOML_PATH_DEFAULT)
  -r, --report-dir            Specify the report output directory (default is $REPORT_DIR_DEFAULT)


Links:
  - Project based on:
    https://github.com/Mirantis/orca/blob/master/perf/README.md

EOF
}

cleanup_cluster_load_resources() {
    local configPath="$1"

    printf "Cleaning up cluster load resources...\n"
    if [ ! -f "$configPath" ]; then
        printf "Error: Cluster load config file '$configPath' not found. Unable to cleanup resources.\n"
        return 1
    fi
    cluster_load_namespace_prefix=$(cat "$configPath" | yq e '.namespace.prefix' -)
    if [ -z "$cluster_load_namespace_prefix" ]; then
        printf "Error: Unable to retrieve cluster namespace prefix. Check if [$configPath] is missing a '.namespace.prefix' value.\n"
        return 1
    fi
    cluster_load_namespaces=$(kubectl get namespaces --no-headers=true | awk -v prefix="$cluster_load_namespace_prefix" '$1 ~ "^" prefix {print $1}')
    if [ -z "$cluster_load_namespaces" ]; then
        printf "Error: Unable to obtain any cluster namespaces prefixed with [$cluster_load_namespace_prefix].\n"
        return 1
    fi
    echo "$cluster_load_namespaces" | xargs kubectl delete namespace
    sleep 120 # Can take a while to work through resource cleanup
    printf "Cleaning up cluster load resources complete.\n"
    return 0
}

get_mke_auth_token() {
    local MKE_USER="$1"
    local MKE_PASSWORD="$2"
    local MKE_URL="$3"

    echo "Obtaining an auth token from MKE..." >&2
    
    local AUTHTOKEN
    AUTHTOKEN=$(curl --retry 5 --retry-max-time 60 --max-time 20 -sk -d "{\"username\":\"$MKE_USER\",\"password\":\"$MKE_PASSWORD\"}" "$MKE_URL/auth/login" | grep -oP '(?<="auth_token":")[^"]*')
    
    if [ -z "$AUTHTOKEN" ]; then
        echo "Error: Unable to obtain auth token from MKE." >&2
        return 1
    fi
    
    echo "Obtaining an auth token from MKE complete." >&2   
    echo "$AUTHTOKEN"
}

# MKE config TOML download
download_mke_config_toml() {
    local MKE_URL="$1"
    local AUTHTOKEN="$2"
    local TOML_FILE_PATH="$3"

    echo "Downloading MKE configuration file to [$TOML_FILE_PATH]..." >&2

    local CONFIG_RESPONSE
    CONFIG_RESPONSE=$(curl --retry 5 --retry-max-time 60 --max-time 20 --silent --insecure -X GET "$MKE_URL/api/ucp/config-toml" -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN")

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


while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -u|--user-num)
            shift
            USER_COUNT_VALUES=()
            while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                if [[ ! "$1" =~ ^[0-9]+$ ]]; then
                    printf "Error: Each user value must be a valid integer.\n"
                    exit 1
                fi
                if (( $1 < $USER_COUNT_MIN || $1 > $USER_COUNT_MAX )); then
                    printf "Error: Each user value must be between $USER_COUNT_MIN and $USER_COUNT_MAX.\n"
                    exit 1
                fi
                USER_COUNT_VALUES+=("$1")
                shift
            done
            continue
            ;;
        -p|--pods-per-node)
            if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                printf "Error: The number of pods per node must be a valid integer after --pods-per-node.\n"
                exit 1
            fi
            if (($2 > $POD_PER_NODE_LIMIT_DEFAULT )); then
                echo
                printf "*Note*: To run more than $POD_PER_NODE_LIMIT_DEFAULT pods-per-node you need to adjust the 'kubelet_max_pods' limit in MKE (config TOML).\n"
                sleep 30 # Enhance to get the value for the cluster and validate
            fi
            PODS_PER_NODE="$2"
            shift
            ;;
        -l|--load)
            LOAD="$2"
            shift
            ;;
        --mke-url)
            MKE_URL="$2"
            shift
            ;;
        --mke-user)
            MKE_USER="$2"
            shift
            ;;
        --mke-password)
            MKE_PASSWORD="$2"
            shift
            ;;
        --mke-config-toml-path)
            if [ -z "$2" ]; then
                printf "Error: The config TOML path must be specified after --mke-config-toml-path.\n"
                exit 1
            fi
            MKE_CONFIG_TOML_PATH="$2"
            shift
            ;;
        -r|--report-dir)
            if [ -z "$2" ]; then
                printf "Error: The report directory must be specified after --report-dir.\n"
                exit 1
            fi
            REPORT_DIR="$2"
            shift
            ;;
    esac
    shift
done

# Dependency checks
if ! command -v terraform &> /dev/null; then
  echo "Error: 'terraform' command line tool not found."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' command line tool not found."
  exit 1
fi

if ! command -v yq &> /dev/null; then
  echo "Error: 'yq' command line tool not found."
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo "Error: 'kubectl' command line tool not found."
  exit 1
fi

script_name="apply_load_to_api.sh"
if [ ! -e "$script_name" ]; then
    printf "Error: The script '$script_name' is not present.\n"
    exit 1
fi

script_name="apply_load_to_cluster.sh"
if [ ! -e "$script_name" ]; then
    printf "Error: The script '$script_name' is not present.\n"
    exit 1
fi
# Validate cluster load
available_loads=$(./"$script_name" -l)
if ! echo "$available_loads" | grep -qw "$LOAD"; then
    printf "Error: Invalid load [$LOAD]. Please provide a valid load from the list:\n"
    echo "$available_loads"
    exit 1
fi

if ! command -v k6 &> /dev/null; then
  echo "Error: 'k6' load testing tool not found."
  exit 1
fi

if [ -z "$MKE_URL" ]; then
  read -p "Enter MKE URL: " MKE_URL
fi
MKE_URL="${MKE_URL%*/}"

if [ -z "$MKE_PASSWORD" ]; then
  read -s -p "Enter MKE password for user [$MKE_USER]: " MKE_PASSWORD
  echo
fi

# Save cluster info for reporting
printf "Obtaining cluster info (terraform output) from the parent directory...\n"
pushd . > /dev/null
cd ..
TF_OUTPUT=$(terraform output -json)
popd > /dev/null
if [ "$TF_OUTPUT" = "{}" ]; then
    printf "Error: Unable to obtain cluster info (terraform output) from the parent directory.\n"
    exit 1
fi
CLUSTER_NAME=$(echo $TF_OUTPUT | jq -r ".cluster_name.value")
if [ -z "$CLUSTER_NAME" ]; then
    printf "Error: Unable to obtain cluster name from terraform output.\n"
    exit 1
fi
MCR_VERSION=$(echo "$TF_OUTPUT" | jq -r '.mke_cluster.value' | yq eval '.spec.mcr.version')
MKE_VERSION=$(echo "$TF_OUTPUT" | jq -r '.mke_cluster.value' | yq eval '.spec.mke.version')
WORKER_COUNT=$(echo "$TF_OUTPUT" | jq -r '.hosts.value[] | select(.instance.tags.Role == "worker") | .instance.instance_type' | wc -l)
WORKER_INSTANCE_TYPE=$(echo "$TF_OUTPUT" | jq -r '.hosts.value[] | select(.instance.tags.Role == "worker") | .instance.instance_type' | head -n 1)
MANAGER_COUNT=$(echo "$TF_OUTPUT" | jq -r '.hosts.value[] | select(.instance.tags.Role == "manager") | .instance.instance_type' | wc -l)
MANAGER_INSTANCE_TYPE=$(echo "$TF_OUTPUT" | jq -r '.hosts.value[] | select(.instance.tags.Role == "manager") | .instance.instance_type' | head -n 1)
printf "Obtaining cluster info from the parent directory complete.\n"

printf "Obtaining cluster info from config TOML...\n"
AUTHTOKEN=$(get_mke_auth_token "$MKE_USER" "$MKE_PASSWORD" "$MKE_URL")
if [ -z "$AUTHTOKEN" ]; then
    printf "Error: Unable to obtain an MKE authtoken.\n"
    exit 1
fi
download_mke_config_toml "$MKE_URL" "$AUTHTOKEN" "$MKE_CONFIG_TOML_PATH"
if [ $? -ne 0 ]; then
    exit 1
fi
PODS_PER_NODE_LIMIT_SETTING=$(grep -Po 'kubelet_max_pods = \K\d+' "$MKE_CONFIG_TOML_PATH" | awk '{print $1}')
ETCD_SIZE_IN_GB_SETTING=$(grep -Po 'etcd_storage_quota = \K"[^"]+"' "$MKE_CONFIG_TOML_PATH" | tr -d '"')
PROM_MEM_LIMIT_IN_GB_SETTING=$(grep -Po 'prometheus_memory_limit = \K"[^"]+"' "$MKE_CONFIG_TOML_PATH" | tr -d '"')
PROM_MEM_REQUEST_IN_GB_SETTING=$(grep -Po 'prometheus_memory_request = \K"[^"]+"' "$MKE_CONFIG_TOML_PATH" | tr -d '"')
PUBKEY_AUTH_CACHE_ENABLED_SETTING=$(awk -F= -v key="pubkey_auth_cache_enabled" '{gsub(/^[ \t]+|[ \t]+$/, "", $1); if ($1 == key) {gsub(/"/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}}' "$MKE_CONFIG_TOML_PATH")
CALICO_KDD_SETTING=$(awk -F= -v key="calico_kdd" '{gsub(/^[ \t]+|[ \t]+$/, "", $1); if ($1 == key) {gsub(/"/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}}' "$MKE_CONFIG_TOML_PATH")
printf "Obtaining cluster info from config TOML complete.\n"

cluster_report_dir="$REPORT_DIR/${LOAD}_${MANAGER_INSTANCE_TYPE}_${CLUSTER_NAME}"
if [ ! -d "$cluster_report_dir" ]; then
    mkdir -p "$cluster_report_dir"
fi
cluster_info=$(jq -n \
  --arg cluster_name "$CLUSTER_NAME" \
  --arg mcr_version "$MCR_VERSION" \
  --arg mke_version "$MKE_VERSION" \
  --arg worker_count "$WORKER_COUNT" \
  --arg worker_instance_type "$WORKER_INSTANCE_TYPE" \
  --arg manager_count "$MANAGER_COUNT" \
  --arg manager_instance_type "$MANAGER_INSTANCE_TYPE" \
  --arg kubelet_max_pods "$PODS_PER_NODE_LIMIT_SETTING" \
  --arg etcd_storage_quota "$ETCD_SIZE_IN_GB_SETTING" \
  --arg prometheus_memory_limit "$PROM_MEM_LIMIT_IN_GB_SETTING" \
  --arg prometheus_request_limit "$PROM_MEM_REQUEST_IN_GB_SETTING" \
  --arg pubkey_auth_cache_enabled "$PUBKEY_AUTH_CACHE_ENABLED_SETTING" \
  --arg calico_kdd "$CALICO_KDD_SETTING" \
  '{
     cluster_name: $cluster_name,
     mcr_version: $mcr_version,
     mke_version: $mke_version,
     worker_count: $worker_count,
     worker_instance_type: $worker_instance_type,
     manager_count: $manager_count,
     manager_instance_type: $manager_instance_type,
     kubelet_max_pods: $kubelet_max_pods,
     etcd_storage_quota: $etcd_storage_quota,
     prometheus_memory_limit: $prometheus_memory_limit,
     prometheus_request_limit: $prometheus_request_limit,
     pubkey_auth_cache_enabled: $pubkey_auth_cache_enabled,
     calico_kdd: $calico_kdd
  }')

printf "Exporting cluster info to [$cluster_report_dir/cluster_info.json]...\n"
echo "$cluster_info" > "$cluster_report_dir/cluster_info.json"
printf "Exporting cluster info to [$cluster_report_dir/cluster_info.json] complete.\n"

# Directory for load specific settings and load output
load_report_dir="$cluster_report_dir/pods_per_node_${PODS_PER_NODE}"
mkdir "$load_report_dir"

# Save cluster load settings for reporting
script_name="apply_load_to_cluster.sh"
cluster_load_settings=$(./"$script_name" -v $LOAD)
cluster_load_settings=$(echo "$cluster_load_settings" | jq ". + { \"NUM_PODS_PER_NODE\": $PODS_PER_NODE }")
cluster_load_settings=$(echo "$cluster_load_settings" | jq ". + { \"LOAD_NAME\": \"$LOAD\" }")
echo "$cluster_load_settings" > "$load_report_dir/cluster_load.json"
# Apply Cluster Load
script_options="--report-dir $load_report_dir/cl2"
script_options="$script_options --pods-per-node $PODS_PER_NODE"
script_options="$script_options $LOAD"
generated_config_path="$load_report_dir/cl2/generatedConfig_load.yaml"
printf "Applying cluster load [$LOAD] with [$PODS_PER_NODE] pods per node...\n"
./"$script_name" $script_options
exit_code=$?
if [ $exit_code -eq 1 ]; then
    printf "Error: Script '$script_name' exited with code $exit_code.\n"
    exit 1
fi
if [ $exit_code -eq 2 ]; then
    printf "Warning: Load tool called by script '$script_name' completed with errors.\n"
fi
printf "Applying cluster load [$LOAD] with [$PODS_PER_NODE] pods per node complete.\n"

wait_in_min=5
printf "Waiting [$wait_in_min] minutes for MKE manager resources to normalize...\n"
sleep "$(echo $wait_in_min)m"
printf "Waiting complete.\n"
if [ -f "$generated_config_path" ]; then
    printf "Gathering some cluster load information...\n"
    cluster_load_namespace_prefix=$(yq e '.namespace.prefix' "$generated_config_path")
    cluster_load_namespaces=$(kubectl get namespaces --no-headers=true | awk -v prefix="$cluster_load_namespace_prefix" '$1 ~ "^" prefix {print $1}')
    for test_namespace in $cluster_load_namespaces; do
        pod_count=$(kubectl get pods --namespace="$test_namespace" --no-headers=true | wc -l)
        total_pod_count=$((total_pod_count + pod_count))
    done
    printf "Total number of pods in namespaces with prefix '$cluster_load_namespace_prefix': $total_pod_count\n"
fi
sleep 10 # Give them a moment to see the pod count

TOTAL_USER_COUNT_VALUES=${#USER_COUNT_VALUES[@]}
for ((i=0; i<TOTAL_USER_COUNT_VALUES; i++)); do
    USER_COUNT=${USER_COUNT_VALUES[i]}
    printf "Measuring MKE API responsiveness under [$LOAD] cluster load with [$USER_COUNT] active MKE users...\n"
    api_report_dir="$load_report_dir/mke_users_${USER_COUNT}"
    mkdir "$api_report_dir"

    # k6 IP allocation (CNI - Calico) performance test where the time it takes to allocate an IP to a Pod is measured
    export BASE_URL="$MKE_URL:6443"
    export VU=$USER_COUNT
    k6 run k6/ip-allocation.js --summary-export=$api_report_dir/k6_api_report_ipalloc.json

    # k6 general performance test where a random user queries resources (pods, secrets, configs, services) from a random namespace
    script_name="apply_load_to_api.sh"
    script_options="--report-dir $api_report_dir"
    script_options="$script_options --namespaces $(echo $cluster_load_settings | jq -r '.NUM_NAMESPACES')"
    script_options="$script_options --users $USER_COUNT"
    if [ -n "$MKE_URL" ]; then
        script_options="$script_options --mke-url $MKE_URL"
    fi
    if [ -n "$MKE_USER" ]; then
        script_options="$script_options --mke-user $MKE_USER"
    fi
    if [ -n "$MKE_PASSWORD" ]; then
        script_options="$script_options --mke-password $MKE_PASSWORD"
    fi
    ./"$script_name" $script_options
    printf "Measuring MKE API responsiveness under [$LOAD] cluster load with [$USER_COUNT] active MKE users complete.\n"

    printf "Obtaining CPU and Memory metrics for MKE Managers...\n"
    AUTHTOKEN=$(curl --retry 5 --retry-max-time 60 --max-time 20 -sk -d "{\"username\":\"$MKE_USER\",\"password\":\"$MKE_PASSWORD\"}" $MKE_URL/auth/login | grep -oP '(?<="auth_token":")[^"]*')
    if [ -z "$AUTHTOKEN" ]; then
        printf "Error: Cannot obtain auth token from MKE. Unable to query cluster for prometheus metrics (CPU and Memory).\n"
    else
        max_attempts=30
        attempt=1
        cpu_query_success=false
        mem_query_success=false
        MANAGER_PRIVATE_IPS=$(echo "$TF_OUTPUT" | jq -r '.hosts.value[] | select(.instance.tags.Role == "manager") | "\(.instance.private_ip):9100"')
        MANAGER_PRIVATE_IPS=$(echo "$MANAGER_PRIVATE_IPS" | tr '\n' '|' | sed 's/|$//')
        QUERY_STRING_CPU="(1 - avg by(instance) (irate(node_cpu_seconds_total{instance=~\"($MANAGER_PRIVATE_IPS)\",mode=\"idle\"}[2m]))) * 100"
        QUERY_STRING_MEM="node_memory_MemTotal_bytes{instance=~\"($MANAGER_PRIVATE_IPS)\"} - node_memory_MemAvailable_bytes{instance=~\"($MANAGER_PRIVATE_IPS)\"}"
        while [ $attempt -le $max_attempts ]; do
            # Peak CPU Usage over 2 minutes
            if [ "$cpu_query_success" != true ]; then
                METRICS_RESPONSE=$(curl --max-time 20 -sk -G "$MKE_URL/metricsservice/query" \
                --data-urlencode "query=$QUERY_STRING_CPU" \
                -H "accept: application/json" \
                -H "Authorization: Bearer $AUTHTOKEN")
                if [ -n "$METRICS_RESPONSE" ]; then
                    if echo "$METRICS_RESPONSE" | jq . >/dev/null 2>&1; then
                        echo "$METRICS_RESPONSE" | jq > "$api_report_dir/mke_managers_cpu_peak.json"
                        cpu_query_success=true
                    else
                        timestamp=$(date "+%Y%m%d%H%M%S")
                        printf "Invalid JSON response received for Prometheus metrics CPU query. See [$api_report_dir/mke_managers_cpu_peak_${timestamp}.err]\n"
                        echo "$METRICS_RESPONSE" > "$api_report_dir/mke_managers_cpu_peak_${timestamp}.err"
                        printf "Attempt $attempt/$max_attempts. Retrying in 10 seconds...\n"
                    fi
                else                
                    printf "Empty response for Prometheus metrics CPU query. Attempt $attempt/$max_attempts. Retrying in 10 seconds...\n"
                fi
            fi
            # Total Memory Used in Bytes
            if [ "$mem_query_success" != true ]; then
                METRICS_RESPONSE=$(curl --max-time 20 -sk -G "$MKE_URL/metricsservice/query" \
                --data-urlencode "query=$QUERY_STRING_MEM" \
                -H "accept: application/json" \
                -H "Authorization: Bearer $AUTHTOKEN")
                if [ -n "$METRICS_RESPONSE" ]; then
                    if echo "$METRICS_RESPONSE" | jq . >/dev/null 2>&1; then
                        echo "$METRICS_RESPONSE" | jq > "$api_report_dir/mke_managers_total_mem_bytes.json"
                        mem_query_success=true
                    else
                        timestamp=$(date "+%Y%m%d%H%M%S")
                        printf "Invalid JSON response received for Prometheus metrics memory query. See [$api_report_dir/mke_managers_total_mem_bytes_${timestamp}.err]\n"
                        echo "$METRICS_RESPONSE" > "$api_report_dir/mke_managers_total_mem_bytes_${timestamp}.err"
                        printf "Attempt $attempt/$max_attempts. Retrying in 10 seconds...\n"
                    fi
                else                
                    printf "Empty response for Prometheus metrics memory query. Attempt $attempt/$max_attempts. Retrying in 10 seconds...\n"
                fi
            fi
            if [ "$cpu_query_success" = true ] && [ "$mem_query_success" = true ]; then
                break  
            fi
            sleep 10
            ((attempt++))            
        done
        if [ $attempt -gt $max_attempts ]; then
            printf "Error: Reached maximum number of attempts CPU and Memory metrics for MKE Managers.\n"
        else
            printf "Obtaining CPU and Memory metrics for MKE Managers complete.\n"
        fi
    fi 
    printf "API test run results saved here: [$api_report_dir].\n"
    if [ $i -lt $((TOTAL_USER_COUNT_VALUES-1)) ]; then
        wait_in_min=1
        printf "Waiting [$wait_in_min] minute(s) between API runs for MKE manager resources to normalize...\n"
        sleep "$(echo $wait_in_min)m"
        printf "Waiting complete.\n"
    fi    
done


# Cleanup Cluster Load
cleanup_cluster_load_resources "$generated_config_path"
printf "Load test run results saved here: [$load_report_dir].\n"
