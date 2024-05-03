apiVersion: boundless.mirantis.com/v1alpha1
kind: Blueprint
metadata:
  name: k0s-cluster
spec:
  kubernetes:
    provider: k0s
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
        controllerManager:
          extraArgs:
            cluster-signing-cert-file: /var/lib/k0s/pki/signing_ca.crt
            cluster-signing-key-file: /var/lib/k0s/pki/signing_ca.key
        storage:
          etcd:
            extraArgs:
              initial-cluster: ${ join(",", [for m in managers : "${m.private_dns}=https://${m.private_ip}:2380"]) }
              initial-cluster-state: existing
    infra:
      hosts:%{ for host in hosts }
        - ssh:
            address: ${host.ssh.address}
            keyPath: ${key_path}
            port: 22
            user: ${host.ssh.user}%{ if host.role == "manager" }
          role: controller+worker%{ else }
          role: worker%{ endif ~}
%{ endfor }
  components:
    addons:
    - name: monitoring
      kind: chart
      enabled: true
      namespace: mke
      chart:
        name: kube-prometheus-stack
        repo: https://prometheus-community.github.io/helm-charts
        version: 57.2.0
        values: |
          grafana:
            enabled: true
    - name: calico-cni
      kind: chart
      enabled: true
      namespace: mke
      chart:
        name: tigera-operator
        repo: https://docs.tigera.io/calico/charts
        version: v3.27.0
        values: |
            installation:
              calicoNetwork:
                bgp: Enabled
