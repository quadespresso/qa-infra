#!/bin/bash
echo "Oracle cloud-init customization"

stop_sshd () {
    # Prevent early logins
    echo "Stopping sshd until reboot"
    systemctl stop sshd
}

fix_selinux () {
    # Correcting for OL 9.0 shortfall.
    # Not an issue running these commands on OL 8.6, 9.1, or 9.2.
    if [[ -f /usr/bin/dnf ]]; then
        dnf -y upgrade selinux-policy
        dnf -y reinstall container-selinux
    fi
}

add_open_ports() {
    # Ensure correct ports are open
    # define contiguous range of ports for inclusion
    PORT_RANGE=({12376..12390}/tcp)
    # define all ports, including prior list
    PORTS=(
        179/tcp
        443/tcp
        2376/tcp
        2377/tcp
        4789/udp
        6443/tcp
        6444/tcp
        7946/tcp
        7946/udp
        9099/tcp
        10250/tcp
    )
    PORTS+=( "${PORT_RANGE[@]}" )

    echo "Adding firewall rules for ports"
    for port in "${PORTS[@]}" ; do
        echo "Enabling firewall port ${port}"
        firewall-offline-cmd --add-port="${port}"
    done
}

replace_kernel() {
    # Replace UEK kernel with RHCK kernel
    echo "Installing RHCK kernel"
    yum -y install kernel
    # determine which installed kernel is RHCK and get the full path
    NEW_KERNEL=$(grubby --info=ALL | awk -F'=' '/vmlinuz-.*.x86_64/ {print $2}' | grep -v 'uek.x86_64' | head -n 1 | tr -d '"') || true
    # update grub config to use RHCK
    echo "Setting RHCK kernel as default"
    grubby --set-default "${NEW_KERNEL}"
}

check_kernel() {
    # Check if the kernel is UEK or RHCK
    UNAME=$(uname -r)
    if [[ "${UNAME}" =~ .*uek\.x86_64 ]]; then
        echo "UEK kernel detected"
        replace_kernel
    else
        echo "RHCK kernel detected"
    fi
}

main() {
    stop_sshd
    fix_selinux
    add_open_ports
    check_kernel
}

# Run the main function
main
