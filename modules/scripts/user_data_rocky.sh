#!/bin/bash
# This script will be executed user_data_linux.sh
# and before the platform-specific script during deployment

# Rocky customization

# EFS setup for NFS mount
yum install -y nfs-utils
mkdir /mnt/efs

# ensure that newly created EFS DNS record will resolve before continuing
until getent hosts ${efs_dns} ; do
    echo "Waiting for ${efs_dns} to become resolvable"
    sleep 5
done
echo "Success - ${efs_dns} can now be resolved"

# mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns}:/ /mnt/efs
echo "${efs_dns}:/  /mnt/efs  nfs  nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport  0 0" >> /etc/fstab
mount /mnt/efs
