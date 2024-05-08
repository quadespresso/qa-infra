hosts:
%{ for host in hosts ~}
%{ if can( host.ssh ) ~}
- ssh:
    user: ${host.ssh.user}
    address: ${host.ssh.address}
    keyPath: ${key_path}
    port: 22
%{ else ~}
- winRM:
    address: ${host.winrm.address}
    user: ${host.winrm.user}
    password: ${host.winrm.password}
    useHTTPS: ${host.winrm.useHTTPS}
    insecure: ${host.winrm.insecure}
%{ endif ~}
  role: %{ if host.role == "manager" }controller+worker%{ else }worker%{ endif }
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
