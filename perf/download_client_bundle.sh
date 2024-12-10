#!/bin/bash

MKE_USER_DEFAULT='admin'
MKE_USER=$MKE_USER_DEFAULT

# Function to display script usage
show_usage() {
    cat <<EOF

Downloads an MKE client bundle

Usage:
  $0 [options]

Options:
  -h, --help                  Display this help message
  --mke-url                   URL to MKE (will be prompted if not supplied)
  --mke-user                  MKE admin user (default is $MKE_USER_DEFAULT)
  --mke-password              MKE user password (will be prompted if not supplied)

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
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
    esac
    shift
done

if [ -z "$MKE_URL" ]; then
  read -p "Enter MKE URL: " MKE_URL
fi
MKE_URL="${MKE_URL%*/}"

if [ -z "$MKE_PASSWORD" ]; then
  read -s -p "Enter MKE password for user [$MKE_USER]: " MKE_PASSWORD
  echo
fi

# Authenticate and get auth token
AUTHTOKEN=$(curl -sk -d \
"{\"username\":\"$MKE_USER\",\"password\":\"$MKE_PASSWORD\"}" \
"$MKE_URL/auth/login" | grep -oP '(?<="auth_token":")[^"]*')

# Download bundle using auth token
curl -k -H "Authorization: Bearer $AUTHTOKEN" \
"$MKE_URL/api/clientbundle" -o "$(echo $MKE_USER)_client_bundle.zip"
