<#
.SYNOPSIS
    Compares MKE performance data between runs (which are grouped by a specified property) where certain columns in rows are identical
.DESCRIPTION
    For every row in the difference data set that matches (based on select columns) a row in the reference
    data set return a row (an object) that includes the matching columns, the compared column from each data
    set, and percent change for the column being compared.
.PARAMETER PerfRunPath
    Path to CSV results that include the reference (how it was before) MKE API performance data set
.PARAMETER PropToGroupBy
    A property found in the runs by which to separate like-for-like runs for comparison
.PARAMETER PropsToMatch
    Properties found in runs that need to be identical for a comparison to be performed
.PARAMETER PropToCompare
    A property found in runs that should be compared and included in the result set
.NOTES
    Author: rleap@mirantis.com
#>
[CmdletBinding()]
param (
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [Parameter(mandatory=$true)]
    [string]
    $PerfRunPath,

    [ValidateNotNullOrEmpty()]
    [Parameter(mandatory=$true)]
    [string]
    $PropToGroupBy,

    [Parameter(mandatory=$false)]
    [string[]]
    $PropsToMatch = @('load_name','manager_instance_type','pods_per_node','virtual_users'),

    [Parameter(mandatory=$false)]
    [string]
    $PropToCompare = 'p95_api_resp_ms'

)

$perfRuns = Import-Csv -Path $PerfRunPath
if ($PropToCompare -notin @($perfRuns | Get-Member | Where-Object -Property MemberType -eq NoteProperty | Select-Object -ExpandProperty Name)) {
    Write-Warning "The property [$PropToCompare] is not in the [$PerfRunPath] data set.  Exiting."
    exit 1
}

# Normalize data - actual virtual users created/used during test run may be slightly less than specified
foreach ($run in $perfRuns) {
    [string] $run.virtual_users = [int]([math]::Ceiling($run.virtual_users/10) * 10)
}

$groupedPerfRuns = $perfRuns | Group-Object -Property $PropToGroupBy
if ($groupedPerfRuns.Count -ne 2) {
    Write-Warning "The property [$PropToGroupBy] is not splitting the runs into two groups for comparsion. Exiting."
}
$refPerfRuns = $groupedPerfRuns[0].Group
$refIdentifier = "$($PropToGroupBy)_$($groupedPerfRuns[0].Name)"
$diffPerfRuns = $groupedPerfRuns[1].Group
$diffIdentifier = "$($PropToGroupBy)_$($groupedPerfRuns[1].Name)"

# These are rows in both data sets where the criteria for comparison match
$rowsToMatch = Compare-Object -ReferenceObject $refPerfRuns -DifferenceObject $diffPerfRuns -Property $PropsToMatch -IncludeEqual -ExcludeDifferent |
    Select-Object -Property $PropsToMatch

# These are the rows in the reference data set that match the criteria for comparison
$perfRuns = $refPerfRuns
$matchingRefRuns = foreach ($row in $rowsToMatch) {
    foreach ($run in $perfRuns) {
        $matchingRun = $true
        foreach ($prop in $PropsToMatch) {
            if ($row.$prop -ne $run.$prop) {
                $matchingRun = $false
                break
            }
        }
        if ($matchingRun) {
            $run
        }
    }
}

# These are the rows in the difference data set that match the criteria for comparison
$perfRuns = $diffPerfRuns
$matchingDiffRuns = foreach ($row in $rowsToMatch) {
    foreach ($run in $perfRuns) {
        $matchingRun = $true
        foreach ($prop in $PropsToMatch) {
            if ($row.$prop -ne $run.$prop) {
                $matchingRun = $false
                break
            }
        }
        if ($matchingRun) {
            $run
        }
    }
}

# Produce output for comparable runs
foreach ($refRun in $matchingRefRuns) {
  foreach ($diffRun in $matchingDiffRuns) {
    $matchingRun = $true
    foreach ($prop in $PropsToMatch) {
      if ($diffRun.$prop -ne $refRun.$prop) {
          $matchingRun = $false
          break
      }
    }
    if ($matchingRun) {
        [int] $refApiP95 = $refRun.$PropToCompare
        [int] $diffApiP95 = $diffRun.$PropToCompare
        if ($refApiP95 -eq 0) {
            $percent = 0
        }
        else {
            $percent = [int]([math]::Round((1 - ($diffApiP95 / $refApiP95)) * 100))
        }
        $comparison = $refRun | Select-Object -Property $PropsToMatch
        Add-Member -InputObject $comparison -NotePropertyName "$($PropToCompare)_w_$($refIdentifier)" -NotePropertyValue $refApiP95
        Add-Member -InputObject $comparison -NotePropertyName "$($PropToCompare)_w_$($diffIdentifier)" -NotePropertyValue $diffApiP95
        Add-Member -InputObject $comparison -NotePropertyName "$($PropToCompare)_perf_gain" -NotePropertyValue $percent -PassThru
    }
  }
}
