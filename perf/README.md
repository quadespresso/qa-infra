# MKE API Load Testing

## Overview

This project is based off [work performed by the MKE Dev Team](https://github.com/Mirantis/orca/blob/master/perf/README.md) on behalf of SocGen.
The aim of the project is to report on MKE API responsiveness under varying cluster and user workloads to help customers make informed decisions
with regard to MKE manager node sizing. This project depends on [ClusterLoader](https://github.com/kubernetes/perf-tests/tree/master/clusterloader2)
to apply a load (k8s resources) to the cluster and on [Grafana k6](https://k6.io/docs/) to simulate users and measure MKE API responsiveness.

## Key Concepts

### Cluster Sizing

The predefined [cluster loads](./loads.json) specify (among other things) the number of worker nodes across which the load (pods)
should be distributed. As such, use Terraform to deploy an MKE cluster with enough worker nodes to accommodate the load that will
be applied.

### Cluster Loads

The [cluster load script](./apply_load_to_cluster.sh) (invoked during a performance run by the [run load test script](./run_load_test.sh))
will apply a predefined [cluster load](./loads.json) (*note*: MKE users are not created by the cluster load script - they come into scope
during API load testing). Additional load definitions may be added to the cluster load file as needed for testing. By default all loads
will include 100 pods-per-node but both the [cluster load script](./apply_load_to_cluster.sh) and the [run load test script](./run_load_test.sh)
(see `--help` for usage) allows the default value to be overridden with the `--pods-per-node` option.

### API Responsiveness

The primary metric being used to determine acceptable cluster performance is when 95% (`p(95)`) of MKE API user requests are serviced in
5 seconds or less. To this end, the [API load script](./apply_load_to_api.sh) is used to record API responsiveness while simulating active
MKE users. This script allows the caller to specify the number of users and namespaces that should be active during the simulation.

### Batch Runs

A template [batch run](./batch_run_load_test.sh) script is provided which shows how to use the [run load test script](./run_load_test.sh) in
succession (a batch) to apply a load to a cluster ([load](./loads.json) + pods per node) and then capture API performance metrics for an
increasing amount of MKE users.

## Usage

### Prereqs

<details>
  <summary><b>Click to expand</b></summary>

From a Linux admin workstation ensure the following binaries are installed:

1. `terraform`, `launchpad`, and `kubectl`
1. `jq` and `yq`
1. `k6` (see [Grafana k6 installation](https://k6.io/docs/get-started/installation/))
1. `clusterloader` (see `--help` in `apply_load_to_cluster.sh` for installation)

</details>

### Setup

<details>
  <summary><b>Click to expand</b></summary>

This [recording](https://drive.google.com/file/d/1VpZWMjwO_QMQ1QsglGxnlmel6hOk5Opw/view?usp=drive_link) is a quick demo of the setup
steps below.

1. Clone the `testing-eng` repo
1. Copy the contents of the `system_test_toolbox\launchpad` directory to a local working directory
1. Deploy an MKE cluster via Terraform/Launchpad ([sized appropriately](#cluster-sizing) for desired peformance test)
1. Login to MKE UI, wait until all nodes are healthy
1. Export variables used by the various load running scripts:
   ```bash
   export CLUSTERLOADERV2_BIN=/<path-to-clusterloader-bin>/cmd/cmd
   export MKE_HOST=...
   export MKE_URL=...
   export MKE_PASSWORD=...
   ```
1. `cd /perf`
1. Increase the pods-per-node limit (if tests will include more than 110 pods-per-node):
   ```bash
   # View
   ./set_mke_pods_per_node_limit.sh -v
   # Update
   ./set_mke_pods_per_node_limit.sh -p 525
   ```
1. Increase the [etcd storage quota](https://docs.mirantis.com/mke/3.7/ops/administer-cluster/manage-etcd/etcd-storage-quota.html?highlight=etcd#configure-etcd-storage-quota):
   ```bash
   # View
   ./set_mke_etcd_storage_quota.sh -v
   # Update
   ./set_mke_etcd_storage_quota.sh -g 8
   ```
1. Increate the [Prometheus memory allocation](https://docs.mirantis.com/mke/3.7/release-notes/3-7-3/known-issues.html?highlight=prometheus_memory_limit#field-6402-default-metric-collection-memory-settings-may-be-insufficient) settings:
   ```bash
   # View
   ./set_mke_prometheus_mem.sh -v

   # Small cluster
   ./set_mke_prometheus_mem.sh -l 8 -r 4

   # Medium cluster
   ./set_mke_prometheus_mem.sh -l 48 -r 24

   # Large cluster
   ./set_mke_prometheus_mem.sh -l 64 -r 32
   ```
1. Apply additional performance tuning settings as necessary for test run:
   ```bash
   # View
   ./set_mke_config_toml_bool.sh -k pubkey_auth_cache_enabled -v
   
   # Enable auth caching
   ./set_mke_config_toml_bool.sh -k pubkey_auth_cache_enabled -b true
   ```
1. Download and apply a client bundle for the `admin` user:
   ```bash
   pushd . > /dev/null
   rm -r ./bundle
   mkdir bundle
   ./download_client_bundle.sh
   mv admin_client_bundle.zip bundle/
   cd bundle
   unzip admin_client_bundle.zip
   source ./env.sh
   popd > /dev/null
   echo "MKE cluster has [$(kubectl get nodes --no-headers | wc -l)] nodes."
   ```
1. Apply a taint to the manager nodes (so that workload pods will be repelled)
   ```bash
   ./apply_taint_to_manager_nodes.sh
   ```
1. Modify and run `batch_run_load_test.sh` to perform a batch run (apply a k8s load, measure api performance for X number of users)

</details>

### Troubleshooting

<details>
  <summary><b>Click to expand</b></summary>

If a run is aborted use the following command to cleanup load resources:

```bash
kubectl get namespaces --no-headers=true | awk '/^test-/ {print $1}' | xargs kubectl delete namespace
```

Monitor the `ucp-metrics` pods (if they enter a crash loop (`OOMKilled`) it is likely because the Prometheus memory allocation settings
for the MKE cluster are insufficient). If the pods do enter a crash loop the load scripts will be unable to obtain MKE Manager CPU and
Memory metrics.

```bash
watch kubectl get pods --namespace kube-system -l k8s-app=ucp-metrics
```

</details>

### Reporting

<details>
  <summary><b>Click to expand</b></summary>

When performance runs are executed against a cluster, performance metrics are saved to a report folder which follows the naming convention
`<load>_<mgr_ec2_instance_type>_<cluster ID>` (e.g. `/reports/medium_r5.8xlarge_85HQ78`). The metrics in this output can then be used to
generate a report. Use the [preprocess_performance_runs.ps1](./preprocess_performance_runs.ps1) script to aggregate the data for multiple
runs from one or more clusters. This script will produce these CSV files from the raw data:

- `cluster_info.csv` - Rows representing cluster make-up
- `cluster_load.csv` - Rows representing load (k8s resource) applied to clusters during runs
- `load_perf_metrics.csv` - Rows representing MKE API performance and MKE Manager CPU and Mem usage during API load tests

The [Compare-MkePerfRuns.ps1](./Compare-MkePerfRuns.ps1) script can be used to compare performance between like-for-like runs
(i.e. medium sized cluster/load; MKE 3.6.4 vs MKE 3.7.3 performance) and the results it provides can also be exported to a CSV
file for use in a report.

Here is a [sample report](https://docs.google.com/spreadsheets/d/1WmsNJz7ZKryMT-aKAa_-kmYFiKWmjtG3-EdsFPzsfyo/edit?usp=sharing) prepared
using the data generated and preprocessed by the tools provided in this project.

</details>
