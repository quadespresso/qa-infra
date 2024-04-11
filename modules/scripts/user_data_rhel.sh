#!/bin/bash
echo "RHEL cloud-init customization"

stop_sshd() {
    # Prevent early logins
    echo "Stopping sshd until reboot"
    systemctl stop sshd
}

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

upgrade_selinux_policy() {
  # needed for RHEL 9.0, to prevent blocked ports during MKE install
  # Ref: https://mirantis.jira.com/browse/PRODENG-2296
  dnf upgrade -y selinux-policy
}

main(){
  RHEL_PROD_VER=$(grep 'REDHAT_SUPPORT_PRODUCT_VERSION' /etc/os-release)
  RHEL_VER=$(echo "${RHEL_PROD_VER}" | grep -Eo '[0-9]+(\.[0-9]+)?')

  stop_sshd

  if [[ "${RHEL_VER}" = "8.4" ]]; then
      disable_nm_cloud_setup
  elif [[ "${RHEL_VER}" = "9.0" ]]; then
      upgrade_selinux_policy
  else
      echo "No special handling needed for RHEL ${RHEL_VER}."
  fi
}

# Run the main function
main
