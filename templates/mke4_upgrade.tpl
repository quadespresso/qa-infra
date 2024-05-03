hosts:
%{ for host in hosts ~}
  - address: ${host.instance.public_ip}
%{ if can( host.ssh ) ~}
    port: 22
    user: ${host.ssh.user}
    keyPath: ${key_path}
%{ endif ~}
%{ endfor }
