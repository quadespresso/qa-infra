#!/usr/bin/env bash

# Exit if any of the intermediate steps fail
set -ex

mkectl init | \
  yq 'with(.spec.hosts; . = env(HOSTS) | ... style="")' | \
  yq '.spec.airgap.enabled = env(AIRGAP)' | \
  yq '.spec.apiServer.externalAddress = env(LB)' | \
  yq '.spec.network.nodePortRange = env(NODE_PORT_RANGE)' | \
  yq '.spec.ingressController.nodePorts.http = env(INGRESS_HTTP_PORT)' | \
  yq '.spec.ingressController.nodePorts.https = env(INGRESS_HTTPS_PORT)' \
  > mke4.yaml

if [[ "${DEV_REGISTRY_ENABLED}" == "true" ]]; then
  yq -i '.spec.registries.chartRegistry.url = "oci://ghcr.io/mirantiscontainers"' mke4.yaml
  yq -i '.spec.registries.imageRegistry.url = "ghcr.io/mirantiscontainers"' mke4.yaml
fi
