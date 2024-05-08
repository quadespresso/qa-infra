hosts:
%{ for host in hosts ~}
  - address: ${host.instance.public_ip}
%{ if can( host.ssh ) ~}
    user: ${host.ssh.user}
%{ else ~}
    user: ${host.winrm.user}
%{ endif ~}
    keyPath: ${key_path}
    port: 22
%{ endfor }
