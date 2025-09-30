#!/bin/bash

MKE_USERNAME=admin
MKE_PASSWORD=$(terraform output --raw admin_password)
MKE_HOST=$(terraform output --raw mke3_external_address)

AUTHTOKEN=$(curl --silent --insecure --data '{"username":"'$MKE_USERNAME'","password":"'$MKE_PASSWORD'"}' https://$MKE_HOST/auth/login | jq --raw-output .auth_token)

case $1 in
  "get")
    curl --silent --insecure -X GET "https://$MKE_HOST/api/ucp/config-toml" -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN" > mke-config.toml
    ;;
  "put")
    curl --silent --insecure -X PUT -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN" --upload-file 'mke-config.toml' https://$MKE_HOST/api/ucp/config-toml
    ;;
  *)
    echo "Usage: $0 get|put"
    exit 1
    ;;
esac
