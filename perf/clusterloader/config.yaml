# Values that should be set when running a test
{{$NUM_WORKER_NODES := DefaultParam .CL2_NUM_WORKER_NODES 3}}
{{$NUM_NAMESPACES := DefaultParam .CL2_NUM_NAMESPACES 25}}
{{$NUM_SECRETS := DefaultParam .CL2_NUM_SECRETS 125}}
{{$NUM_CONFIGMAPS := DefaultParam .CL2_NUM_CONFIGMAPS 125}}
{{$NUM_SERVICES := DefaultParam .CL2_NUM_SERVICES 50}}
{{$PODS_PER_NODE := DefaultParam .CL2_PODS_PER_NODE 100}}
{{$DEPLOYMENTS_PER_NAMESPACE := DefaultParam .CL2_DEPLOYMENTS_PER_NAMESPACE 1}}

# Variables calculated based on input values
{{$totalPods := MultiplyInt $NUM_WORKER_NODES $PODS_PER_NODE}}
{{$podsPerNamespace := DivideInt $totalPods $NUM_NAMESPACES}}
{{$podsPerDeployment := DivideInt $podsPerNamespace $DEPLOYMENTS_PER_NAMESPACE}}
{{$secretsPerNamespace := DivideInt $NUM_SECRETS $NUM_NAMESPACES}}
{{$configmapsPerNamespace := DivideInt $NUM_CONFIGMAPS $NUM_NAMESPACES}}
{{$servicesPerNamespace := DivideInt $NUM_SERVICES $NUM_NAMESPACES}}

name: load
namespace:
  number: {{$NUM_NAMESPACES}}
  deleteAutoManagedNamespaces: false
tuningSets:
  - name: Uniform1qps
    qpsLoad:
      qps: 1
steps:
  - name: Start measurements
    measurements:
      - Identifier: PodStartupLatency
        Method: PodStartupLatency
        Params:
          action: start
          labelSelector: group = test-pod
          threshold: 60s
      - Identifier: WaitForControlledPodsRunning
        Method: WaitForControlledPodsRunning
        Params:
          action: start
          apiVersion: apps/v1
          kind: Deployment
          labelSelector: group = test-deployment
          operationTimeout: 120s

  - name: Create cluster resources
    phases:
      - namespaceRange:
          min: 1
          max: {{$NUM_NAMESPACES}}
        replicasPerNamespace: {{$DEPLOYMENTS_PER_NAMESPACE}}
        tuningSet: Uniform1qps
        objectBundle:
          - basename: test-deployment
            objectTemplatePath: "deployment.yaml"
            templateFillMap:
              Replicas: {{$podsPerDeployment}}
      - namespaceRange:
          min: 1
          max: {{$NUM_NAMESPACES}}
        replicasPerNamespace: {{$secretsPerNamespace}}
        tuningSet: Uniform1qps
        objectBundle:
          - basename: test-secret
            objectTemplatePath: "secret.yaml"
      - namespaceRange:
          min: 1
          max: {{$NUM_NAMESPACES}}
        replicasPerNamespace: {{$configmapsPerNamespace}}
        tuningSet: Uniform1qps
        objectBundle:
          - basename: test-configmap
            objectTemplatePath: "configmap.yaml"
      - namespaceRange:
          min: 1
          max: {{$NUM_NAMESPACES}}
        replicasPerNamespace: {{$servicesPerNamespace}}
        tuningSet: Uniform1qps
        objectBundle:
          - basename: test-service
            objectTemplatePath: "service.yaml"

  - name: Wait for pods to be running
    measurements:
      - Identifier: WaitForControlledPodsRunning
        Method: WaitForControlledPodsRunning
        Params:
          action: gather
  - name: Measure pod startup latency
    measurements:
      - Identifier: PodStartupLatency
        Method: PodStartupLatency
        Params:
          action: gather
