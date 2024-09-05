#!/bin/bash
#
# Uses this flavour of 'yq':
#   https://github.com/mikefarah/yq
#

MKE4_INSTALL="mke4_install.yaml"
NEW_MKE4_INSTALL="mke4.yaml"

MKE4_HOSTS_MOD_TMP=$(mktemp)
MKE4_INIT_TMP=$(mktemp)
MKE4_NEW_YAML_TMP=$(mktemp)

cleanup() {
  rm -f "$MKE4_YAML_TMP" "$MKE4_NEW_YAML_TMP" "$MKE4_HOSTS_MOD_TMP"
}

# Trap the signals and call the cleanup function
trap cleanup EXIT INT TERM

# Make sure temp files don't exist
cleanup

# Modify the original mke4_install.yaml in-place
# ingress_controller_replicas mke4_install.yaml

yq eval '.spec.hosts' mke4_install.yaml | yq '{"hosts": .}' | yq '{"spec": .}' > "${MKE4_HOSTS_MOD_TMP}"

# Craft the 'yq' command to modify the 'mkectl init' output
REPLICA_CT=$(terraform output -raw ingress_controller_replicas)
REPLICA_CT_JSONPATH='.spec.ingressController.replicaCount'
YQ_UPD_CMD="mkectl init | yq '${REPLICA_CT_JSONPATH} = ${REPLICA_CT}' > ${MKE4_INIT_TMP}"
# echo "${YQ_UPD_CMD}"
eval "${YQ_UPD_CMD}"

# Craft the 'yq' file merge command
YQ_MERGE_CMD="yq -n 'load(\"${MKE4_INIT_TMP}\") * load(\"${MKE4_HOSTS_MOD_TMP}\")' > ${MKE4_NEW_YAML_TMP}"
# echo "${YQ_MERGE_CMD}"
eval "${YQ_MERGE_CMD}"

mv "$MKE4_NEW_YAML_TMP" "$NEW_MKE4_INSTALL"

echo
echo "File updated: ${NEW_MKE4_INSTALL}"
echo
echo "Run command:  mkectl apply -f ${NEW_MKE4_INSTALL}"

# The temp files are deleted automatically when the script exits or is interrupted
