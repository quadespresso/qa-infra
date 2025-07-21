<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.3.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_common"></a> [common](#module\_common) | ./modules/common | n/a |
| <a name="module_efs"></a> [efs](#module\_efs) | ./modules/efs | n/a |
| <a name="module_elb_mke"></a> [elb\_mke](#module\_elb\_mke) | ./modules/elb | n/a |
| <a name="module_elb_mke4"></a> [elb\_mke4](#module\_elb\_mke4) | ./modules/elb | n/a |
| <a name="module_elb_msr"></a> [elb\_msr](#module\_elb\_msr) | ./modules/elb | n/a |
| <a name="module_managers"></a> [managers](#module\_managers) | ./modules/linux | n/a |
| <a name="module_msrs"></a> [msrs](#module\_msrs) | ./modules/linux | n/a |
| <a name="module_tls"></a> [tls](#module\_tls) | ./modules/tls | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./modules/vpc | n/a |
| <a name="module_windows_workers"></a> [windows\_workers](#module\_windows\_workers) | ./modules/windows | n/a |
| <a name="module_workers"></a> [workers](#module\_workers) | ./modules/linux | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.ansible_inventory](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.blueprint](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.k0sctl](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.launchpad_yaml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.mke4_install](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.mke4_upgrade](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.nodes_yaml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.prepare_temp_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.prepare_temp_tls_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.random](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_static.now](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | The MKE admin password to use. | `string` | `"orcaorcaorca"` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | The MKE admin username to use. | `string` | `"admin"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region to deploy to. | `string` | `"us-west-2"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Global cluster name. Use this to override a dynamically created name. | `string` | `""` | no |
| <a name="input_enable_fips"></a> [enable\_fips](#input\_enable\_fips) | Enable FIPS mode on the cluster. Be mindful of 'ssh\_algorithm' compatibility. | `bool` | `false` | no |
| <a name="input_expire_duration"></a> [expire\_duration](#input\_expire\_duration) | The max time to allow this cluster to avoid early termination. Can use 'h', 'm', 's' in sane combinations, eg, '15h37m18s'. | `string` | `"120h"` | no |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | A map of arbitrary, customizable string key/value pairs to be included alongside a preset map of tags to be used across myriad AWS resources. | `map(string)` | `{}` | no |
| <a name="input_hooks_apply_after"></a> [hooks\_apply\_after](#input\_hooks\_apply\_after) | A list of strings (shell commands) to be run after stages. | `list(string)` | <pre>[<br>  ""<br>]</pre> | no |
| <a name="input_hooks_apply_before"></a> [hooks\_apply\_before](#input\_hooks\_apply\_before) | A list of strings (shell commands) to be run before stages. | `list(string)` | <pre>[<br>  ""<br>]</pre> | no |
| <a name="input_ingress_controller_replicas"></a> [ingress\_controller\_replicas](#input\_ingress\_controller\_replicas) | Number of replicas for the ingress controller ('ingressController.replicaCount' in the MKE installer YAML file). | `number` | `2` | no |
| <a name="input_kube_orchestration"></a> [kube\_orchestration](#input\_kube\_orchestration) | The option to enable/disable Kubernetes as the default orchestrator. | `bool` | `true` | no |
| <a name="input_life_cycle"></a> [life\_cycle](#input\_life\_cycle) | Deploy instances as either 'spot' or 'ondemand' | `string` | `"ondemand"` | no |
| <a name="input_manager_count"></a> [manager\_count](#input\_manager\_count) | The number of MKE managers to create. | `number` | n/a | yes |
| <a name="input_manager_type"></a> [manager\_type](#input\_manager\_type) | The AWS instance type to use for manager nodes. | `string` | `"m5.xlarge"` | no |
| <a name="input_manager_volume_size"></a> [manager\_volume\_size](#input\_manager\_volume\_size) | The volume size (in GB) to use for manager nodes. | `number` | `50` | no |
| <a name="input_mcr_channel"></a> [mcr\_channel](#input\_mcr\_channel) | The channel to pull the mcr installer from. | `string` | n/a | yes |
| <a name="input_mcr_install_url_linux"></a> [mcr\_install\_url\_linux](#input\_mcr\_install\_url\_linux) | Location of Linux installer script. | `string` | `"https://get.mirantis.com/"` | no |
| <a name="input_mcr_install_url_windows"></a> [mcr\_install\_url\_windows](#input\_mcr\_install\_url\_windows) | Location of Windows installer script. | `string` | `"https://get.mirantis.com/install.ps1"` | no |
| <a name="input_mcr_repo_url"></a> [mcr\_repo\_url](#input\_mcr\_repo\_url) | The repository to source the mcr installer. | `string` | `"https://repos-internal.mirantis.com"` | no |
| <a name="input_mcr_version"></a> [mcr\_version](#input\_mcr\_version) | The mcr version to deploy across all nodes in the cluster. | `string` | n/a | yes |
| <a name="input_mke_image_repo"></a> [mke\_image\_repo](#input\_mke\_image\_repo) | The repository to pull the MKE images from. | `string` | `"msr.ci.mirantis.com/mirantiseng"` | no |
| <a name="input_mke_install_flags"></a> [mke\_install\_flags](#input\_mke\_install\_flags) | The MKE installer flags to use. | `list(string)` | `[]` | no |
| <a name="input_mke_version"></a> [mke\_version](#input\_mke\_version) | The MKE version to deploy. | `string` | n/a | yes |
| <a name="input_msr_count"></a> [msr\_count](#input\_msr\_count) | The number of MSR replicas to create. | `number` | n/a | yes |
| <a name="input_msr_enable_nfs"></a> [msr\_enable\_nfs](#input\_msr\_enable\_nfs) | Option to configure EFS/NFS for use with MSR 2.x | `bool` | `true` | no |
| <a name="input_msr_image_repo"></a> [msr\_image\_repo](#input\_msr\_image\_repo) | The repository to pull the MSR images from. | `string` | `"msr.ci.mirantis.com/msr"` | no |
| <a name="input_msr_install_flags"></a> [msr\_install\_flags](#input\_msr\_install\_flags) | The MSR installer flags to use. | `list(string)` | <pre>[<br>  "--ucp-insecure-tls"<br>]</pre> | no |
| <a name="input_msr_replica_config"></a> [msr\_replica\_config](#input\_msr\_replica\_config) | Set to 'sequential' to generate sequential replica id's for cluster members, for example 000000000001, 000000000002, etc. ('random' otherwise) | `string` | `"sequential"` | no |
| <a name="input_msr_target_port"></a> [msr\_target\_port](#input\_msr\_target\_port) | The target port for MSR LoadBalancer should lead to this port on the MSR replicas. | `string` | `"443"` | no |
| <a name="input_msr_type"></a> [msr\_type](#input\_msr\_type) | The AWS instance type to use for MSR replica nodes. | `string` | `"m5.xlarge"` | no |
| <a name="input_msr_version"></a> [msr\_version](#input\_msr\_version) | The MSR version to deploy. | `string` | `""` | no |
| <a name="input_msr_volume_size"></a> [msr\_volume\_size](#input\_msr\_volume\_size) | The volume size (in GB) to use for MSR replica nodes. | `number` | `50` | no |
| <a name="input_open_sg_for_myip"></a> [open\_sg\_for\_myip](#input\_open\_sg\_for\_myip) | If true, allow ALL traffic, ANY protocol, originating from the terraform execution source IP. Use sparingly. | `bool` | `false` | no |
| <a name="input_platform"></a> [platform](#input\_platform) | The Linux platform to use for manager/worker/MSR replica nodes | `string` | `"ubuntu_20.04"` | no |
| <a name="input_project"></a> [project](#input\_project) | One of the official cost-tracking project names. Without this, your cluster may get terminated without warning. | `string` | `"UNDEFINED"` | no |
| <a name="input_role_platform"></a> [role\_platform](#input\_role\_platform) | Platform names based on role. Linux-only, Windows uses win\_platform only. | `map(any)` | <pre>{<br>  "manager": null,<br>  "msr": null,<br>  "worker": null<br>}</pre> | no |
| <a name="input_ssh_algorithm"></a> [ssh\_algorithm](#input\_ssh\_algorithm) | n/a | `string` | `"ED25519"` | no |
| <a name="input_ssh_key_file_path"></a> [ssh\_key\_file\_path](#input\_ssh\_key\_file\_path) | If non-empty, use this path/filename as the ssh key file instead of generating automatically. | `string` | `""` | no |
| <a name="input_task_name"></a> [task\_name](#input\_task\_name) | An arbitrary yet unique string which represents the deployment, eg, 'refactor', 'unicorn', 'stresstest'. | `string` | `"UNDEFINED"` | no |
| <a name="input_username"></a> [username](#input\_username) | A string which represents the engineer running the test. | `string` | `"UNDEFINED"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | The CIDR to use when creating the VPC. | `string` | `"172.31.0.0/16"` | no |
| <a name="input_win_admin_password"></a> [win\_admin\_password](#input\_win\_admin\_password) | The Windows Administrator password to use. | `string` | `"tfaws,,ABC..Example"` | no |
| <a name="input_win_platform"></a> [win\_platform](#input\_win\_platform) | The Windows platform to use for worker nodes | `string` | `"windows_2019"` | no |
| <a name="input_win_worker_volume_size"></a> [win\_worker\_volume\_size](#input\_win\_worker\_volume\_size) | The volume size (in GB) to use for Windows worker nodes. | `number` | `50` | no |
| <a name="input_windows_worker_count"></a> [windows\_worker\_count](#input\_windows\_worker\_count) | The number of MKE Windows workers to create. | `number` | n/a | yes |
| <a name="input_worker_count"></a> [worker\_count](#input\_worker\_count) | The number of MKE Linux workers to create. | `number` | n/a | yes |
| <a name="input_worker_type"></a> [worker\_type](#input\_worker\_type) | The AWS instance type to use for Linux/Windows worker nodes. | `string` | `"m5.large"` | no |
| <a name="input_worker_volume_size"></a> [worker\_volume\_size](#input\_worker\_volume\_size) | The volume size (in GB) to use for worker nodes. | `number` | `50` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ansible_inventory"></a> [ansible\_inventory](#output\_ansible\_inventory) | n/a |
| <a name="output_aws_region"></a> [aws\_region](#output\_aws\_region) | n/a |
| <a name="output_blueprint"></a> [blueprint](#output\_blueprint) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_hosts"></a> [hosts](#output\_hosts) | n/a |
| <a name="output_k0sctl"></a> [k0sctl](#output\_k0sctl) | n/a |
| <a name="output_launchpad"></a> [launchpad](#output\_launchpad) | n/a |
| <a name="output_mke4_install"></a> [mke4\_install](#output\_mke4\_install) | n/a |
| <a name="output_mke4_lb"></a> [mke4\_lb](#output\_mke4\_lb) | n/a |
| <a name="output_mke4_upgrade"></a> [mke4\_upgrade](#output\_mke4\_upgrade) | n/a |
| <a name="output_mke_cluster"></a> [mke\_cluster](#output\_mke\_cluster) | n/a |
| <a name="output_mke_lb"></a> [mke\_lb](#output\_mke\_lb) | n/a |
| <a name="output_mke_san"></a> [mke\_san](#output\_mke\_san) | Use this output is you are trying to build your own launchpad yaml and need the value for "--san={} |
| <a name="output_mkectl_upgrade_command"></a> [mkectl\_upgrade\_command](#output\_mkectl\_upgrade\_command) | n/a |
| <a name="output_msr_lb"></a> [msr\_lb](#output\_msr\_lb) | n/a |
| <a name="output_nfs_server"></a> [nfs\_server](#output\_nfs\_server) | n/a |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | n/a |
| <a name="output_nodes_yaml"></a> [nodes\_yaml](#output\_nodes\_yaml) | n/a |
<!-- END_TF_DOCS -->
