%{ for i, host in hosts ~}
Host ${host.role}-${i}
    HostName ${host.ssh.address}
    User ${host.ssh.user}
    IdentityFile ${key_path}
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null

%{ endfor ~}
