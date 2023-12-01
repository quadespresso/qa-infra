#!/bin/bash

TIME=$(date +'%Y%m%d-%H%M%S')
REPORT_DIR_DEFAULT="/tmp/reports/cl2/$TIME"
REPORT_DIR=$REPORT_DIR_DEFAULT
POD_PER_NODE_MIN=10
POD_PER_NODE_MAX=550
POD_PER_NODE_LIMIT_DEFAULT=110
PODS_PER_NODE_DEFAULT=100
PODS_PER_NODE=$PODS_PER_NODE_DEFAULT
LOAD_CONFIG_PATH=./loads.json

# Function to display script usage
show_usage() {
    cat <<EOF

Applies a load (spins up k8s resources) to an MKE cluster via the ClusterLoader Tool

Usage:
  $0 [options] [small|medium|large|<etc.>]

Options:
  -h, --help            Display this help message
  -l, --list            List loads available to apply
  -v, --view            Display load settings for a named load
  -p, --pods-per-node   Specify the number of pods per node (default is $PODS_PER_NODE_DEFAULT)
  -r, --report-dir      Specify the report output directory (default is $REPORT_DIR_DEFAULT)

Requirements:
  1. Running a Linux environment
  2. Appropriately sized MKE cluster running in AWS
  3. Tainted master nodes (so that pods will be scheduled to workers):
     \$ kubectl taint nodes \$(kubectl get nodes -l node-role.kubernetes.io/master= |awk '{if(NR>1)print \$1}') type=master:NoSchedule
  4. The 'jq' and 'kubectl' utilities in the path
  5. KUBECONFIG env var set
  6. ClusterLoader binary accessible via 'CLUSTERLOADERV2_BIN' env variable. To build this binary:
     a. git clone git@github.com:kubernetes/perf-tests.git
     b. cd perf-tests/clusterloader2/cmd
     c. go build (see https://go.dev/doc/install to install Go)
     d. This will build the cluster loader binary 'cmd'
     e. Set CLUSTERLOADERV2_BIN=/path/to/clusterloader2/cmd/cmd

Notes:
  The ClusterLoader tool loads are defined here: $LOAD_CONFIG_PATH
  You can add additional loads to the file as needed and specify the load by name for use with this script.

  The ClusterLoader tool will create a namespace for itself and several resources by which to operate:
  $ kubectl get all -n cluster-loader

  The ClusterLoader tool will create load resources in namespaces prefixed with 'test-'.  See output:
  $ kubectl get namespaces | grep '^test-'

  To clean up the load resources:
  $ kubectl get namespaces --no-headers=true | awk '/^test-/ {print \$1}' | xargs kubectl delete namespace

Links:
  - Script based on work done here by MKE Team:
    https://github.com/Mirantis/orca/tree/master/perf
  - Kubernetes ClusterLoader Tool
    https://github.com/kubernetes/perf-tests/tree/master/clusterloader2
  - Setting up Grafana in MKE
    https://docs.mirantis.com/mke/3.7/ops/administer-cluster/collect-cluster-metrics-prometheus/set-up-grafana.html

EOF
}

if ! command -v jq &> /dev/null; then
    printf "Error: 'jq' not found.\n"
    show_usage
    exit 1
fi

show_loads() {
    jq -r '.loads | keys[]' "$LOAD_CONFIG_PATH"
}

show_load_settings() {
    if ! jq -e ".loads[\"$LOAD\"]" "$LOAD_CONFIG_PATH" > /dev/null; then
      echo "Error: Load size [$LOAD] not found in the config file."
      exit 1
    fi
    # printf "Cluster load [$LOAD] has the following settings:\n"
    jq ".loads[\"$LOAD\"]" "$LOAD_CONFIG_PATH"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -p|--pods-per-node)
            if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                printf "Error: The number of pods per node must be a valid integer after --pods-per-node.\n"
                exit 1
            fi
            if (( $2 < $POD_PER_NODE_MIN || $2 > $POD_PER_NODE_MAX )); then
                printf "Error: The number of pods per node must be between $POD_PER_NODE_MIN and $POD_PER_NODE_MAX.\n"
                exit 1
            fi
            if (($2 > $POD_PER_NODE_LIMIT_DEFAULT )); then
                echo
                printf "*Note*: To run more than $POD_PER_NODE_LIMIT_DEFAULT pods-per-node you need to adjust the 'kubelet_max_pods' limit in MKE (config TOML).\n"
            fi
            PODS_PER_NODE="$2"
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
        -l|--list)
            show_loads
            exit 0
            ;;
        -v|--view)
            VIEW_ONLY=true
            ;;
        *)
            # Assume it's the load argument
            LOAD="$1"
            ;;
    esac
    shift
done

if [ ! -f "$LOAD_CONFIG_PATH" ]; then
    echo "Error: The config file [$LOAD_CONFIG_PATH] does not exist."
    exit 1
fi

if [ -z "$LOAD" ]; then
    echo "Error: Please provide a value for the load to apply to the cluster."
    show_usage
    exit 1
fi

if ! jq -e ".loads[\"$LOAD\"]" "$LOAD_CONFIG_PATH" > /dev/null; then
    echo "Error: Load size [$LOAD] not found in [$LOAD_CONFIG_PATH]. Please specify one of the following loads:"
    show_loads
    exit 1
fi

if [ "$VIEW_ONLY" = true ]; then
    show_load_settings
    exit 0
fi

if [ -n "$CLUSTERLOADERV2_BIN" ]; then
    if [ ! -f "$CLUSTERLOADERV2_BIN" ]; then
        echo "Error: The file [$CLUSTERLOADERV2_BIN] referenced by the CLUSTERLOADERV2_BIN env var does not exist."
        exit 1
    fi
else
    echo "Error: The 'CLUSTERLOADERV2_BIN' env var is not set."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo "Error: 'kubectl' not found."
  exit 1
fi

if [ -n "$KUBECONFIG" ]; then
    if [ ! -f "$KUBECONFIG" ]; then
        echo "Error: The file [$KUBECONFIG] referenced by the KUBECONFIG env var does not exist."
        exit 1
    fi
else
    echo "Error: The 'KUBECONFIG' env var is not set."
    exit 1
fi

TESTCONFIG_PATH=./clusterloader/config.yaml
if [ ! -f "$TESTCONFIG_PATH" ]; then
    echo "Error: The ClusterLoader config file [$TESTCONFIG_PATH] does not exist."
    exit 1
fi

# Run the cluster loader tool
export CL2_PODS_PER_NODE=$PODS_PER_NODE
export CL2_NUM_WORKER_NODES=$(jq -r ".loads[\"$LOAD\"].NUM_WORKER_NODES" "$LOAD_CONFIG_PATH")
export CL2_NUM_NAMESPACES=$(jq -r ".loads[\"$LOAD\"].NUM_NAMESPACES" "$LOAD_CONFIG_PATH")
export CL2_NUM_SECRETS=$(jq -r ".loads[\"$LOAD\"].NUM_SECRETS" "$LOAD_CONFIG_PATH")
export CL2_NUM_CONFIGMAPS=$(jq -r ".loads[\"$LOAD\"].NUM_CONFIGMAPS" "$LOAD_CONFIG_PATH")
export CL2_NUM_SERVICES=$(jq -r ".loads[\"$LOAD\"].NUM_SERVICES" "$LOAD_CONFIG_PATH")
WORKER_NODE_COUNT=$(kubectl get nodes --selector='!node-role.kubernetes.io/master' --no-headers | wc -l)
if (($WORKER_NODE_COUNT < $CL2_NUM_WORKER_NODES )); then
    echo "Error: Load [$LOAD] requires [$CL2_NUM_WORKER_NODES] worker nodes. Cluster only has [$WORKER_NODE_COUNT] worker nodes."
    exit 1
fi
$CLUSTERLOADERV2_BIN --testconfig="$TESTCONFIG_PATH" --provider=aws --kubeconfig=$KUBECONFIG --v=2 --report-dir="$REPORT_DIR"
if [ $? -ne 0 ]; then
    exit 2  # Use a different exit code for command-line utility errors
fi
