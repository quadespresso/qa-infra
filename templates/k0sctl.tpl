apiVersion: k0sctl.k0sproject.io/v1beta1
kind: Cluster
metadata:
  name: k0s-cluster
spec:
  hosts:%{ for host in hosts }
    - ssh:
        address: ${host.ssh.address}
        keyPath: ${key_path}
        port: 22
        user: ${host.ssh.user}%{ if host.role == "manager" }
      role: controller+worker%{ else }
      role: worker%{ endif ~}
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
