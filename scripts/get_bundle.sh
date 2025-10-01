#!/usr/bin/env bash

ls | grep -v "get_bundle.sh\|values.sysdig.yaml\|scan_sysdig.sh" | xargs rm -rf

#sudo apt-get install -y unzip jq
#sudo snap install --classic kubectl

MKE_IP=$1

# Create an environment variable with the user security token
AUTHTOKEN=$(curl -sk -d '{"username":"admin","password":"orcaorcaorca"}' https://$MKE_IP/auth/login | jq -r .auth_token)

# Download the client certificate bundle
curl -k -H "Authorization: Bearer $AUTHTOKEN" https://$MKE_IP/api/clientbundle -o bundle.zip

# Unzip the bundle.
unzip bundle.zip

# Run the utility script.
eval "$(<env.sh)"
