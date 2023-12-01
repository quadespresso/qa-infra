# Scrub bad API response result
$mke364Path = 'C:\Users\rleap\Documents\tf-lp\mke_373_load_tests\reports\processed\mke_3.7.3_results.csv'
Import-Csv -Path $mke364Path | Where-Object -Property p95_api_resp_ms -ne 0 | Export-Csv -Path $mke364Path -Force

# MKE 3.6.4 vs 3.7.3 (where manager node count matches)
$propsToMatch = @('load_name','manager_instance_type','pods_per_node','virtual_users','manager_count')
$comparisonPath = 'C:\Users\rleap\Documents\tf-lp\mke_373_load_tests\reports\processed\mke_364_vs_373_p95_api_comparision.csv'
$splat = @{
    'PropsToMatch'         = $propsToMatch
    'ReferenceCsvPath'     = 'C:\Users\rleap\Documents\tf-lp\mke_373_load_tests\reports\processed\mke_3.6.4_results.csv'
    'ReferenceIdentifier'  = '364'
    'DifferenceCsvPath'    = 'C:\Users\rleap\Documents\tf-lp\mke_373_load_tests\reports\processed\mke_3.7.3_results.csv'
    'DifferenceIdentifier' = '373'
    'PropToCompare'        = 'p95_api_resp_ms'
}
.\Compare-MkePerfRuns.ps1 @splat | Where-Object -Property load_name -NotIn @('xsmall','small') | Export-Csv -Path $comparisonPath -Force

# MKE 3.7.3 (3 mgr) vs 3.7.3 (5 mgr)
$perfResultsMke373 = Import-Csv -Path 'C:\Users\rleap\Documents\tf-lp\mke_373_load_tests\reports\processed\mke_3.7.3_results.csv'
$mgrCount3Path = 'C:\Users\rleap\Documents\tf-lp\mke_373_load_tests\reports\processed\mke_3.7.3_3mgr_results.csv'
$mgrCount5Path = 'C:\Users\rleap\Documents\tf-lp\mke_373_load_tests\reports\processed\mke_3.7.3_5mgr_results.csv'
$perfResultsMke373 | Where-Object -Property 'manager_count' -eq '3' | Export-Csv -Path $mgrCount3Path -Force
$perfResultsMke373 | Where-Object -Property 'manager_count' -eq '5' | Export-Csv -Path $mgrCount5Path -Force
$propsToMatch = @('load_name','manager_instance_type','pods_per_node','virtual_users')
$comparisonPath = 'C:\Users\rleap\Documents\tf-lp\mke_373_load_tests\reports\processed\mke_373_3mgr_vs_mke_373_5mgr_p95_api_comparision.csv'
$splat = @{
    'PropsToMatch'         = $propsToMatch
    'ReferenceCsvPath'     = $mgrCount3Path
    'ReferenceIdentifier'  = '373_3mgr'
    'DifferenceCsvPath'    = $mgrCount5Path
    'DifferenceIdentifier' = '373_5mgr'
    'PropToCompare'        = 'p95_api_resp_ms'
}
.\Compare-MkePerfRuns.ps1 @splat | Where-Object -Property load_name -NotIn @('xsmall','small') | Export-Csv -Path $comparisonPath -Force
