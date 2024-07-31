
[CmdletBinding()]
param (
    [string] $ReportPath = (Join-Path -Path $env:USERPROFILE -ChildPath 'Documents\tf-lp\calico_perf_test_runs')
)

# Flatten the data
.\preprocess_performance_runs.ps1 -PerfRunPath $ReportPath -AddlClusterInfoProps @('calico_kdd') -Verbose

# Make comparsion worksheets
$comparisonReportList = @()
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_general.csv'
    ApiTest       = 'general'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'mgr_peak_cpu_avg_pct'
}
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_general.csv'
    ApiTest       = 'general'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'mgr_peak_mem_avg_gb'
}
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_general.csv'
    ApiTest       = 'general'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'http_req_duration_p95_ms'
}
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_general.csv'
    ApiTest       = 'general'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'http_req_duration_med_ms'
}
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_general.csv'
    ApiTest       = 'general'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'http_req_duration_avg_ms'
}
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_ipalloc.csv'
    ApiTest       = 'ipalloc'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'mgr_peak_cpu_avg_pct'
}
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_ipalloc.csv'
    ApiTest       = 'ipalloc'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'mgr_peak_mem_avg_gb'
}
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_ipalloc.csv'
    ApiTest       = 'ipalloc'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'http_req_duration_p95_ms'
}
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_ipalloc.csv'
    ApiTest       = 'ipalloc'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'http_req_duration_med_ms'
}
$comparisonReportList += [PSCustomObject]@{
    ReportPath    = (Join-Path -Path $ReportPath -ChildPath 'processed')
    Prefix        = 'calico_etcd_vs_kdd'
    PerfFile      = 'load_perf_metrics_ipalloc.csv'
    ApiTest       = 'ipalloc'
    PropToGroupBy = 'calico_kdd'
    PropToCompare = 'http_req_duration_avg_ms'
}

foreach ($comparisonReport in $comparisonReportList) {
    $splat = @{
        PerfRunPath   = (Join-Path -Path $comparisonReport.ReportPath -ChildPath $comparisonReport.PerfFile)
        PropToGroupBy = $comparisonReport.PropToGroupBy
        PropToCompare = $comparisonReport.PropToCompare
    }
    $comparisonReportFile = $comparisonReport.Prefix + '_' + $comparisonReport.PropToCompare + '_' + $comparisonReport.ApiTest + '.csv'
    Write-Verbose "Exporting API load comparison to [$(Join-Path -Path $comparisonReport.ReportPath -ChildPath $comparisonReportFile)]"
    .\Compare-MkePerfRunsGrouped.ps1 @splat -Verbose | Export-Csv -Path (Join-Path -Path $comparisonReport.ReportPath -ChildPath $comparisonReportFile)
}

Get-Childitem -Path (Join-Path -Path (Join-Path -Path $ReportPath -ChildPath 'processed') -ChildPath 'calico_etcd_vs_kdd_*.csv') | 
ForEach-Object {
    Write-Verbose "Results from [$($_.Name)]"
    Import-Csv -Path $_.FullName | Format-Table -Wrap
}