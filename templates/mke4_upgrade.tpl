hosts:
%{ for host in hosts ~}
%{ if can( host.ssh ) ~}
  - address: ${host.instance.public_ip}
    user: ${host.ssh.user}
    keyPath: ${key_path}
    port: 22
%{ endif ~}
%{ endfor }
