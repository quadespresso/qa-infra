apiVersion: mke.mirantis.com/v1alpha1
kind: MkeConfig
metadata:
  name: mke
  namespace: mke
spec:
  hosts:
    %{~ for host in hosts ~}
    %{~ if can( host.ssh ) ~}
    - ssh:
        address: ${host.ssh.address}
        keyPath: ${key_path}
        port: 22
        user: ${host.ssh.user}%{ if host.role == "manager" }
      role: controller+worker%{ else }
      role: worker%{ endif }
    %{~ endif ~}
  %{~ endfor ~}
  authentication:
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
        nodeport: 33100
  tracking:
    enabled: true
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
      defaultSslCertificate: mke/mke-ingress.tls
  monitoring:
    enableGrafana: true
    enableOpscare: false
  network:
    kubeProxy:
      disabled: false
      mode: iptables
      metricsBindAddress: 0.0.0.0:10249
      iptables:
        masqueradeBit: null
        masqueradeAll: false
        localhostNodePorts: null
        syncPeriod: 0s
        minSyncPeriod: 0s
      ipvs:
        syncPeriod: 0s
        minSyncPeriod: 0s
        scheduler: ""
        excludeCIDRs: []
        strictARP: false
        tcpTimeout: 0s
        tcpFinTimeout: 0s
        udpTimeout: 0s
      nodePortAddresses: []
    nllb:
      disabled: true
    cplb:
      disabled: true
    providers:
      - provider: calico
        enabled: true
        extraConfig:
          CALICO_DISABLE_FILE_LOGGING: "true"
          CALICO_STARTUP_LOGLEVEL: DEBUG
          FELIX_LOGSEVERITYSCREEN: DEBUG
          clusterCIDRIPv4: 192.168.0.0/16
          deployWithOperator: "false"
          enableWireguard: "false"
          ipAutodetectionMethod: ""
          mode: vxlan
          overlay: Always
          vxlanPort: "4789"
          vxlanVNI: "10000"
      - provider: kuberouter
        enabled: false
        extraConfig:
          deployWithOperator: "false"
      - provider: custom
        enabled: false
        extraConfig:
          deployWithOperator: "false"
