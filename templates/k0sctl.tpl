apiVersion: k0sctl.k0sproject.io/v1beta1
kind: Cluster
metadata:
  name: k0s-cluster
spec:
  hosts:%{ for host in hosts }
    %{~ if can( host.ssh ) ~}
    - ssh:
        user: ${host.ssh.user}
        address: ${host.ssh.address}
        keyPath: ${key_path}
        port: 22
    %{~ else ~}
    - winRM:
        address: ${host.winrm.address}
        user: ${host.winrm.user}
        password: ${host.winrm.password}
        useHTTPS: ${host.winrm.useHTTPS}
        insecure: ${host.winrm.insecure}
    %{~ endif ~}
      role: %{ if host.role == "manager" }controller+worker%{ else }worker%{ endif ~}
%{ endfor }
  k0s:
    config:
      apiVersion: k0s.k0sproject.io/v1beta1
      kind: Cluster
      metadata:
        name: k0s
      spec:
        network:
          provider: calico
        api:
          sans:
            - ${mke_san}
          extraArgs:
            encryption-provider-config: /var/lib/k0s/pki/encryption.cfg
        storage:
          etcd:
            extraArgs:
              initial-cluster: ${ join(",", [for m in managers : "${m.private_dns}=https://${m.private_ip}:2380"]) }
              initial-cluster-state: existing
