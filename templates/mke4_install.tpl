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
  externalAddress: ${lb}
  sans: []
ingressController:
  enabled: true
  replicaCount: ${ingress_controller_replicas}
  extraArgs:
    httpPort: 80
    httpsPort: 443
    enableSslPassthrough: false
    defaultSslCertificate: mke/auth-https.tls
monitoring:
  enableGrafana: true
  enableOpscare: false
network:
  kubeProxy:
    disabled: false
    mode: iptables
    metricsbindaddress: 0.0.0.0:10249
    iptables:
      masqueradebit: null
      masqueradeall: false
      localhostnodeports: null
      syncperiod:
        duration: 0s
      minsyncperiod:
        duration: 0s
    ipvs:
      syncperiod:
        duration: 0s
      minsyncperiod:
        duration: 0s
      scheduler: ""
      excludecidrs: []
      strictarp: false
      tcptimeout:
        duration: 0s
      tcpfintimeout:
        duration: 0s
      udptimeout:
        duration: 0s
    nodeportaddresses: []
  nllb:
    disabled: true
  cplb:
    disabled: true
  providers:
    - provider: calico
      enabled: true
      CALICO_DISABLE_FILE_LOGGING: true
      CALICO_STARTUP_LOGLEVEL: DEBUG
      FELIX_LOGSEVERITYSCREEN: DEBUG
      clusterCIDRIPv4: 192.168.0.0/16
      deployWithOperator: false
      enableWireguard: false
      ipAutodetectionMethod: null
      mode: vxlan
      overlay: Always
      vxlanPort: 4789
      vxlanVNI: 10000
      windowsNodes: false
    - provider: kuberouter
      enabled: false
      deployWithOperator: false
    - provider: custom
      enabled: false
      deployWithOperator: false
