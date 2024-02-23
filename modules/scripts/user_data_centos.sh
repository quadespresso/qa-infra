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
