#!/bin/bash
echo "CentOS cloud-init customization"

FILE="/etc/system-release-cpe"

if [ -e $FILE ]; then
    echo "Verified $FILE exists."
    major_ver=$(awk -F: '{print $NF}' $FILE | awk -F. '{print $1}')
    echo "Major version is $major_ver"
    repo_url="https://dl.fedoraproject.org/pub/epel/epel-release-latest-${major_ver}.noarch.rpm"
    echo "Installing: $repo_url"
    rpm -Uvh "${repo_url}"
    echo "Installing jq and tmux"
    yum install -y jq tmux
else
    echo "File $FILE does not exist. Unable to proceed with installing utils such as jq and tmux."
    exit 1
fi

add_open_ports() {
    # Ensure correct ports are open
    # define contiguous range of ports for inclusion
    PORT_RANGE=({12376..12392}/tcp)
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
        9055/tcp
        9091/tcp
        9099/tcp
        9100/tcp
        10248/tcp
        10250/tcp
    )
    PORTS+=( "${PORT_RANGE[@]}" )

    echo "Adding firewall rules for ports"
    for port in "${PORTS[@]}" ; do
        echo "Enabling firewall port ${port}"
        firewall-offline-cmd --add-port="${port}"
    done
}

main() {
    add_open_ports
}

# Run the main function
main
