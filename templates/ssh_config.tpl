%{ for i, host in hosts ~}
Host ${host.role}-${i}
    HostName ${try(host.ssh.address, host.winrm.address)}
    User ${try(host.ssh.user, host.winrm.user)}
    IdentityFile ${key_path}
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null

%{ endfor ~}
