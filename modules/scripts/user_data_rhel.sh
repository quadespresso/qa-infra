#!/bin/bash
echo "RHEL cloud-init customization"

disable_nm_cloud_setup() {
  # disable component uniquely problematic to RHEL 8.4 for MKE
  echo "Running 'systemctl disable nm-cloud-setup.timer'"
  systemctl disable nm-cloud-setup.timer || true

  echo "Running 'systemctl disable nm-cloud-setup.service'"
  systemctl disable nm-cloud-setup.service || true

  echo "Running 'yum -y remove NetworkManager-cloud-setup'"
  yum -y remove NetworkManager-cloud-setup

  echo "Running 'ip rule show' (before changes)"
  ip rule show

  echo "Running command and assigning output to var from_ip: ip rule show | awk '/30400:/ {print \$2, \$3}'"
  from_ip="$(ip rule show | awk '/30400:/ {print $2" "$3}')"

  echo "Running 'eval ip rule delete \"\${from_ip}\"' (removes problematic rule)"
  # we use 'eval' because $from_ip is treated like a single string instead of 2 strings separated by a space
  eval ip rule delete "${from_ip}"

  echo "Running 'ip rule del table 30400'"
  ip route flush table 30400

  echo "Running 'ip rule show' (after changes)"
  ip rule show
}

if grep -q 'REDHAT_SUPPORT_PRODUCT_VERSION="8.4"' /etc/os-release; then
    # Call the function to disable nm cloud setup
    disable_nm_cloud_setup
else
    echo "REDHAT_SUPPORT_PRODUCT_VERSION is not 8.4."
fi
