<#
.SYNOPSIS
    Process MKE load results and output the relevant data into CSV files
.PARAMETER PerfRunPath
    Path to cluster performance run output
.NOTES
    Author: Ryan Leap - rleap@mirantis.com
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]
    $PerfRunPath
)

# See https://www.powershellgallery.com/packages/PSSharedGoods/0.0.31/Content/Public%5CObjects%5CMerge-Objects.ps1
function Merge-Objects {
    [CmdletBinding()]
    param (
        [Object] $Object1,
        [Object] $Object2
    )
    $Object = [ordered] @{}
    foreach ($Property in $Object1.PSObject.Properties) {
        $Object += @{$Property.Name = $Property.Value}

    }
    foreach ($Property in $Object2.PSObject.Properties) {
        $Object += @{$Property.Name = $Property.Value}
    }
    return [PSCustomObject] $Object
}

$clusterInfoFile = 'cluster_info.json'
$clusterInfoOutputPath = Join-Path -Path $PerfRunPath -ChildPath 'processed' -AdditionalChildPath $clusterInfoFile.Replace('json','csv')
$clusterInfoList = [System.Collections.Generic.List[PSCustomObject]]::new()

$clusterLoadFile = 'cluster_load.json'
$clusterLoadOutputPath = Join-Path -Path $PerfRunPath -ChildPath 'processed' -AdditionalChildPath $clusterLoadFile.Replace('json','csv')
$clusterLoadList = [System.Collections.Generic.List[PSCustomObject]]::new()

$k6LoadFile = 'k6_api_report.json'
$mgrMetricsCpuLoadFile = 'mke_managers_cpu_peak.json'
$mgrMetricsMemLoadFile = 'mke_managers_total_mem_bytes.json'
$apiMetricsList = [System.Collections.Generic.List[PSCustomObject]]::new()
$apiMetricsOutputPath = Join-Path -Path $PerfRunPath -ChildPath 'processed' -AdditionalChildPath 'load_perf_metrics.csv'

$loadsFile = 'loads.json'
$loadConfigsOutputPath = Join-Path -Path $PerfRunPath -ChildPath 'processed' -AdditionalChildPath 'load_configs.csv'

# Each Cluster
$clusterInfoByPath = Get-ChildItem -Path $PerfRunPath -Exclude 'aborted_runs', 'processed' -Directory
foreach ($clusterPath in $clusterInfoByPath) {
    $clusterInfoFilePath = Join-Path -Path $clusterPath -ChildPath $clusterInfoFile
    if (Test-Path -Path $clusterInfoFilePath -PathType Leaf) {
        $clusterInfo = Get-Content -Path $clusterInfoFilePath | ConvertFrom-Json
        $clusterInfoList.Add($clusterInfo)
    }
    else {
        Write-Warning "File [$clusterInfoFilePath] is missing."
    }
    # Each Cluster Load
    $clusterLoadByPath = Get-ChildItem -Path (Join-Path $clusterPath -ChildPath 'pods_per_node_*') -Directory
    foreach ($clusterLoadPath in $clusterLoadByPath) {
        $clusterLoadFilePath = Join-Path -Path $clusterLoadPath -ChildPath $clusterLoadFile
        if (Test-Path -Path $clusterLoadFilePath -PathType Leaf) {
            $clusterLoad = Get-Content -Path $clusterLoadFilePath | ConvertFrom-Json | Select-Object -Property @{Name='CLUSTER_NAME';Expression={$clusterInfo.cluster_name}},*
            $clusterLoadList.Add($clusterLoad)
        }
        else {
            Write-Warning "File [$clusterLoadFilePath] is missing."
        }
        # Each MKE User API Load
        $mkeUserLoadByPath = Get-ChildItem -Path (Join-Path $clusterLoadPath -ChildPath 'mke_users_*') -Directory
        foreach ( $mkeUserLoadPath in $mkeUserLoadByPath) {
            Add-Member -InputObject $mkeUserLoadPath -NotePropertyName 'Users' -NotePropertyValue ([int]($mkeUserLoadPath.Name -split '_')[2])
        }
        $mkeUserLoadByPath = $mkeUserLoadByPath | Sort-Object -Property Users
        foreach ($mkeUserLoadPath in $mkeUserLoadByPath) {
            $k6FilePath = Join-Path -Path $mkeUserLoadPath -ChildPath $k6LoadFile
            if (Test-Path -Path $k6FilePath -PathType Leaf) {
                $k6Load = Get-Content -Path $k6FilePath | ConvertFrom-Json
                $k6LoadCustom = [PSCustomObject]@{
                    virtual_users         = $k6Load.metrics.vus.max
                    p95_api_resp_ms       = [math]::Round($k6Load.metrics.http_req_duration.'p(95)', 2)
                    script_iterations     = $k6Load.metrics.iterations.count
                    effective_req_per_sec = [math]::Round($k6load.metrics.http_reqs.count / 60,1)
                }
            }
            else {
                $k6LoadCustom = [PSCustomObject]@{
                    virtual_users         = 0
                    p95_api_resp_ms       = 0.0
                    script_iterations     = 0
                    effective_req_per_sec = 0.0
                }
                Write-Warning "File [$k6FilePath] missing!"
            }
            $mgrMetricsCpuLoadFilePath = Join-Path -Path $mkeUserLoadPath -ChildPath $mgrMetricsCpuLoadFile
            if (Test-Path -Path $mgrMetricsCpuLoadFilePath -PathType Leaf) {
                $mgrMetricsCpuLoad = Get-Content -Path $mgrMetricsCpuLoadFilePath | ConvertFrom-Json
                $mgrPeakCpu = foreach ($metric in $mgrMetricsCpuLoad.data.result) {
                    [math]::Round($metric.value[1],2)
                }
                $mgrPeakCpuAvg = [math]::Round(($mgrPeakCpu | Measure-Object -Average).Average,2)
            }
            else {
                $mgrPeakCpuAvg = 0.0
                Write-Warning "File [$mgrMetricsCpuLoadFilePath] missing!"                
            }
            $mgrMetricsMemLoadFilePath = Join-Path -Path $mkeUserLoadPath -ChildPath $mgrMetricsMemLoadFile
            if (Test-Path -Path $mgrMetricsMemLoadFilePath -PathType Leaf) {
                $mgrMetricsMemLoad = Get-Content -Path $mgrMetricsMemLoadFilePath | ConvertFrom-Json
                $mgrPeakMemBytes = foreach ($metric in $mgrMetricsMemLoad.data.result) {
                    $metric.value[1]
                }
                $mgrPeakMemGbAvg = [math]::Round(($mgrPeakMemBytes | Measure-Object -Average).Average / 1GB, 2)
            }
            else {
                $mgrPeakMemGbAvg = 0.0
                Write-Warning "File [$mgrMetricsMemLoadFilePath] missing!"                
            }
            $apiLoad = [PSCustomObject]@{
                mke_version           = $clusterInfo.mke_version
                cluster_name          = $clusterLoad.CLUSTER_NAME
                load_name             = $clusterLoad.LOAD_NAME
                manager_count         = $clusterInfo.manager_count
                manager_instance_type = $clusterInfo.manager_instance_type
                worker_count          = $clusterInfo.worker_count
                pods_per_node         = $clusterLoad.NUM_PODS_PER_NODE
                total_test_pods       = ([int] $clusterLoad.NUM_PODS_PER_NODE) * ([int] $clusterInfo.worker_count)
            }
            $apiLoad = Merge-Objects -Object1 $apiLoad -Object2 $k6LoadCustom
            $apiLoad = $apiLoad | Select-Object -Property *,@{Name='mgr_peak_cpu_avg_pct'; Expression={$mgrPeakCpuAvg}},
                                                            @{Name='mgr_peak_mem_avg_gb'; Expression={$mgrPeakMemGbAvg}}
            $apiMetricsList.Add($apiLoad)
        }
    }
}

if (Test-Path -Path (Join-Path -Path '.' -ChildPath $loadsFile) -PathType Leaf) {
    $loads = Get-Content -Raw ".\$loadsFile" | ConvertFrom-Json
    $loadNames = @($loads.loads | get-member | where-Object -Property MemberType -ne 'Method' | Select-Object -ExpandProperty Name)
    $loadsFlattened = foreach ($loadName in $loadNames) {
        $loads.loads.$loadName | Select-Object -Property @{Name = 'load_name'; Expression = {$loadName}},
        @{Name = 'num_worker_nodes'; Expression = {$_.NUM_WORKER_NODES}},
        @{Name = 'num_namespaces'; Expression = {$_.NUM_NAMESPACES}},
        @{Name = 'num_secrets'; Expression = {$_.NUM_SECRETS}},
        @{Name = 'num_configmaps'; Expression = {$_.NUM_CONFIGMAPS}},
        @{Name = 'num_services'; Expression = {$_.NUM_SERVICES}}
    }
    Write-Verbose "Exporting API loads to [$loadConfigsOutputPath]"
    $loadsFlattened | Sort-Object -Property num_worker_nodes | Export-Csv -Path $loadConfigsOutputPath -Force
}
if ($clusterInfoList.Count -gt 0) {
    Write-Verbose "Exporting cluster info to [$clusterInfoOutputPath]"
    $clusterInfoList | Sort-Object { [int]$_.worker_count } | Export-Csv -Path $clusterInfoOutputPath -Force
}
if ($clusterLoadList.Count -gt 0) {
    Write-Verbose "Exporting cluster loads to [$clusterLoadOutputPath]"
    $clusterLoadList | Sort-Object -Property NUM_WORKER_NODES | Export-Csv -Path $clusterLoadOutputPath -Force
}
if ($apiMetricsList.Count -gt 0) {
    Write-Verbose "Exporting API loads to [$apiMetricsOutputPath]"
    $apiMetricsList | Export-Csv -Path $apiMetricsOutputPath -Force
    $loadConfigs = import-csv $loadConfigsOutputPath | Select-Object -Property load_name,num_worker_nodes
    foreach ($apiMetric in $apiMetricsList) {
        $workerNodeCount = ($loadConfigs | Where-Object -Property 'load_name' -eq $apiMetric.load_name).num_worker_nodes
        Add-Member -InputObject $apiMetric -NotePropertyName 'worker_nodes' -NotePropertyValue $workerNodeCount
    }
    $apiMetricsList | Sort-Object -Property {[int] $_.worker_nodes }, 'cluster_name', {[int] $_.pods_per_node},
      {[int] $_.virtual_users} | Select-Object -Property * -ExcludeProperty 'worker_nodes' | Export-Csv -Path $apiMetricsOutputPath -Force  
}
