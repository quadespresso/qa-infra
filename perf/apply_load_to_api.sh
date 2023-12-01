#!/bin/bash

REPORT_DIR_DEFAULT="/tmp/reports/k6"
REPORT_DIR=$REPORT_DIR_DEFAULT
MKE_USER_DEFAULT='admin'
MKE_USER=$MKE_USER_DEFAULT
NAMESPACE_COUNT_DEFAULT=25
NAMESPACE_COUNT=$NAMESPACE_COUNT_DEFAULT
USER_COUNT_DEFAULT=20
USER_COUNT=$USER_COUNT_DEFAULT
USER_COUNT_MIN=1
USER_COUNT_MAX=1000
NAMESPACE_MIN=1
NAMESPACE_MAX=5000

# Function to display script usage
show_usage() {
    cat <<EOF

Measures MKE API responsiveness when applying a simulated user load
(requesting K8s resources) using the Grafana k6 tool

Usage:
  $0 [options]

Options:
  -h, --help                  Display this help message
  -n, --namespaces            Number of namespaces (default is $NAMESPACE_COUNT_DEFAULT) in simulated load
  -u, --users                 Number of users (default is $USER_COUNT_DEFAULT) in simulated load
  --mke-url                   URL to MKE
  --mke-user                  MKE admin user (default is $MKE_USER_DEFAULT)
  --mke-password              MKE user password
  -r, --report-dir            Specify the report output directory (default is $REPORT_DIR_DEFAULT)

Links:
  - Based on:
    https://github.com/Mirantis/orca/blob/master/perf/README.md#api-load-test
  - Installing Grafana k6
    https://k6.io/docs/get-started/installation/

EOF
}

show_load() {
    echo
    printf "API load has the following settings:\n"
    printf "%-20s %-20s\n" "MKE Users:" "$USER_COUNT"
    printf "%-20s %-20s\n" "Namespaces:" "$NAMESPACE_COUNT"
    echo
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -n|--namespaces)
            if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                printf "Error: The number of namespaces must be a valid integer.\n"
                exit 1
            fi
            if (( $2 < $NAMESPACE_MIN || $2 > $NAMESPACE_MAX )); then
                printf "Error: The number of namespaces must be between $NAMESPACE_MIN and $NAMESPACE_MAX.\n"
                exit 1
            fi
            NAMESPACE_COUNT="$2"
            shift
            ;;
        -u|--users)
            if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                printf "Error: The number of users must be a valid integer.\n"
                exit 1
            fi
            if (( $2 < $USER_COUNT_MIN || $2 > $USER_COUNT_MAX )); then
                printf "Error: The number of namespaces must be between $USER_COUNT_MIN and $USER_COUNT_MAX.\n"
                exit 1
            fi
            USER_COUNT="$2"
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

AUTHTOKEN=$(curl -sk -d "{\"username\":\"$MKE_USER\",\"password\":\"$MKE_PASSWORD\"}" $MKE_URL/auth/login | grep -oP '(?<="auth_token":")[^"]*')
if [ -z "$AUTHTOKEN" ]; then
    echo "Error obtaining auth token from MKE. Exiting."
    exit 1
fi 
printf "Obtaining an auth token from MKE complete\n"

export VU=$USER_COUNT
export NUM_NAMESPACES=$NAMESPACE_COUNT
export BASE_URL=$MKE_URL
export MKE_AUTHTOKEN=$AUTHTOKEN
show_load
REPORT_DIR_DEFAULT="/tmp/reports/k6/$TIME"
if [ ! -d "$REPORT_DIR" ]; then
    mkdir -p "$REPORT_DIR"
fi

k6 run k6/script.js --summary-export=$REPORT_DIR/k6_api_report.json
