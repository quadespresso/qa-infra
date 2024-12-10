# Original YAML found here:
# https://docs.mirantis.com/mke/3.7/ops/administer-cluster/collect-cluster-metrics-prometheus/set-up-grafana.html
#
# Change made to this manifest from the original docs:
#   - Includes a toleration for a type=master:NoSchedule taint
#
# After deploying, you can access the Grafana UI as follows:
#
#   Port forwarding via http://localhost:3000/
#   $ kubectl -n monitoring port-forward service/grafana 3000:3000
#
#   alternatively:
#
#   With a LB via http://<node-public-ip>:<node-port>/
#   $ kubectl -n monitoring expose svc grafana --type=LoadBalancer --name=grafana-public-elb
#   $ kubectl -n monitoring patch svc grafana-public-elb -p '{"spec": {"type": "LoadBalancer", "externalIPs":["<node-public-ip>","<node-public-ip>"]}}'
#   $ kubectl -n monitoring get svc grafana-public-elb
#
#   Troubleshooting Grafana deployment:
#   $ kubectl -n monitoring get all
#   $ kubectl -n monitoring describe configmap grafana-config


if ! command -v kubectl &> /dev/null; then
  echo "Error: 'kubectl' not found."
  exit 1
fi

if [ -n "$KUBECONFIG" ]; then
    if [ ! -f "$KUBECONFIG" ]; then
        echo "Error: The file [$KUBECONFIG] referenced by the KUBECONFIG env var does not exist."
        exit 1
    fi
else
    echo "Error: The 'KUBECONFIG' env var is not set."
    exit 1
fi

kubectl create namespace monitoring
CLUSTER_ID=$(docker info --format '{{json .Swarm.Cluster.ID}}')
kubectl apply -f - <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: grafana
  name: grafana
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      securityContext:
        runAsUser: 0
      tolerations:
      - key: "type"
        operator: "Equal"
        value: "master"
        effect: "NoSchedule"
      containers:
        - name: grafana
          image: grafana/grafana:9.1.0-ubuntu
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
              name: http-grafana
              protocol: TCP
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /robots.txt
              port: 3000
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 30
            successThreshold: 1
            timeoutSeconds: 2
          livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            tcpSocket:
              port: 3000
            timeoutSeconds: 1
          resources:
            requests:
              cpu: 250m
              memory: 750Mi
          volumeMounts:
            - mountPath: /etc/grafana/
              name: grafana-config-volume
            - mountPath: /etc/ssl
              name: ucp-node-certs
      volumes:
        - name: grafana-config-volume
          configMap:
            name: grafana-config
            items:
              - key: grafana.ini
                path: grafana.ini
              - key: dashboard.json
                path: dashboard.json
              - key: datasource.yml
                path: provisioning/datasources/datasource.yml
        - name: ucp-node-certs
          hostPath:
            path: /var/lib/docker/volumes/ucp-node-certs/_data
      nodeSelector:
        node-role.kubernetes.io/master: ""
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  ports:
    - port: 3000
      protocol: TCP
      targetPort: http-grafana
  selector:
    app: grafana
  sessionAffinity: None
  type: ClusterIP
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-config
  namespace: monitoring
  labels:
    grafana_datasource: '1'
data:
  grafana.ini: |
  dashboard.json: |
  datasource.yml: |-
    apiVersion: 1
    datasources:
    - name: mke-prometheus
      type: prometheus
      access: proxy
      orgId: 1
      url: https://ucp-metrics.kube-system.svc.cluster.local:443
      jsonData:
        tlsAuth: true
        tlsAuthWithCACert: false
        serverName: $CLUSTER_ID
      secureJsonData:
        tlsClientCert: "\$__file{/etc/ssl/cert.pem}"
        tlsClientKey: "\$__file{/etc/ssl/key.pem}"
---
EOF
