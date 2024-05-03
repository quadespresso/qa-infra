hosts:
%{ for host in hosts ~}
- ssh:
    address: ${host.ssh.address}
%{ if can( host.ssh ) ~}
    user: ${host.ssh.user}
    keyPath: ${key_path}
    port: 22
  role: %{ if host.role == "manager" }controller+worker%{ else }worker%{ endif }
%{ endif ~}
%{ endfor ~}
hardening:
  enabled: true
authentication:
  enabled: true
  saml:
    enabled: false
  oidc:
    enabled: false
  ldap:
    enabled: false
backup:
  enabled: true
  storage_provider:
    type: InCluster
    in_cluster_options:
      exposed: true
tracking:
  enabled: true
trust:
  enabled: true
logging:
  enabled: true
audit:
  enabled: true
license:
  refresh: true
apiServer:
  sans: []
ingressController:
  enabled: false
monitoring:
  enableGrafana: true
  enableOpscare: false
