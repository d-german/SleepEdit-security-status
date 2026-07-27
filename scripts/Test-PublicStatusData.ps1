[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $StatusPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-ExactProperties {
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)][string[]] $Expected,
        [Parameter(Mandatory)][string] $Path
    )

    if ($null -eq $Object) {
        throw "$Path must be an object."
    }

    $actual = @($Object.PSObject.Properties.Name | Sort-Object)
    $expectedSorted = @($Expected | Sort-Object)
    if (Compare-Object $actual $expectedSorted) {
        throw "$Path has missing or unapproved properties. Expected: $($expectedSorted -join ', '). Actual: $($actual -join ', ')."
    }
}

function Assert-NullableNumber {
    param($Value, [string] $Path, [double] $Minimum = 0, [double] $Maximum = [double]::MaxValue)

    if ($null -eq $Value) { return }
    if ($Value -isnot [ValueType] -or [double]$Value -lt $Minimum -or [double]$Value -gt $Maximum) {
        throw "$Path must be null or a number between $Minimum and $Maximum."
    }
}

$resolvedStatusPath = (Resolve-Path -LiteralPath $StatusPath).Path
$raw = Get-Content -LiteralPath $resolvedStatusPath -Raw
$status = $raw | ConvertFrom-Json

if ($raw -match '(?i)(password|private[-_ ]?key|secret|token|stack trace|\\|/[A-Za-z0-9_.-]+/.*\.(cs|cshtml|ps1)|<script|javascript:)') {
    throw "The public status contains prohibited sensitive or executable content."
}

Assert-ExactProperties $status @('schemaVersion','product','source','commit','scanDateUtc','overall','dependencies','staticAnalysis','quality','tests','tooling') '$'
Assert-ExactProperties $status.dependencies @('status','nuget','npm') '$.dependencies'
Assert-ExactProperties $status.dependencies.nuget @('total','critical','high','moderate','low') '$.dependencies.nuget'
Assert-ExactProperties $status.dependencies.npm @('total','critical','high','moderate','low') '$.dependencies.npm'
Assert-ExactProperties $status.staticAnalysis @('status','qualityGate','vulnerabilities','securityHotspots','securityHotspotsReviewedPercent','documentedExceptions','securityRating') '$.staticAnalysis'
Assert-ExactProperties $status.quality @('coveragePercent','lineCoveragePercent','branchCoveragePercent','complexity','cognitiveComplexity','duplicatedLinesDensityPercent','bugs','codeSmells','maintainabilityRating','linesOfCode') '$.quality'
Assert-ExactProperties $status.tests @('status','total','passed','failed','skipped') '$.tests'
Assert-ExactProperties $status.tooling @('sonarQubeVersion','sonarScannerVersion') '$.tooling'

if ($status.schemaVersion -ne 1 -or $status.product -ne 'SleepEdit' -or $status.source -ne 'private-release-workflow') {
    throw 'The public status identity or schema version is invalid.'
}

$allowedStatuses = @('pending','passed','failed')
foreach ($entry in @($status.overall, $status.dependencies.status, $status.staticAnalysis.status, $status.tests.status)) {
    if ($entry -notin $allowedStatuses) { throw "Unapproved status value: $entry" }
}
if ($status.staticAnalysis.qualityGate -notin @('pending','passed','failed','none')) {
    throw "Unapproved quality gate value: $($status.staticAnalysis.qualityGate)"
}
if ($null -ne $status.commit -and $status.commit -notmatch '^[0-9a-f]{7,40}$') {
    throw 'Commit must be null or a hexadecimal Git commit identifier.'
}
if ($null -ne $status.scanDateUtc) {
    $parsedDate = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$status.scanDateUtc, [ref]$parsedDate)) {
        throw 'scanDateUtc must be null or an ISO-8601 timestamp.'
    }
}

foreach ($ecosystem in @($status.dependencies.nuget, $status.dependencies.npm)) {
    foreach ($name in @('total','critical','high','moderate','low')) {
        Assert-NullableNumber $ecosystem.$name "dependency.$name"
    }
}
foreach ($name in @('vulnerabilities','securityHotspots','documentedExceptions')) {
    Assert-NullableNumber $status.staticAnalysis.$name "staticAnalysis.$name"
}
Assert-NullableNumber $status.staticAnalysis.securityHotspotsReviewedPercent 'staticAnalysis.securityHotspotsReviewedPercent' 0 100
Assert-NullableNumber $status.staticAnalysis.securityRating 'staticAnalysis.securityRating' 1 5
foreach ($name in @('coveragePercent','lineCoveragePercent','branchCoveragePercent','duplicatedLinesDensityPercent')) {
    Assert-NullableNumber $status.quality.$name "quality.$name" 0 100
}
foreach ($name in @('complexity','cognitiveComplexity','bugs','codeSmells','linesOfCode')) {
    Assert-NullableNumber $status.quality.$name "quality.$name"
}
Assert-NullableNumber $status.quality.maintainabilityRating 'quality.maintainabilityRating' 1 5
foreach ($name in @('total','passed','failed','skipped')) {
    Assert-NullableNumber $status.tests.$name "tests.$name"
}
foreach ($name in @('sonarQubeVersion','sonarScannerVersion')) {
    $value = $status.tooling.$name
    if ($null -ne $value -and [string]$value -notmatch '^\d+(\.\d+){1,3}([+-][0-9A-Za-z.-]+)?$') {
        throw "tooling.$name must be null or a version identifier."
    }
}

Write-Host "Validated sanitized public status: $resolvedStatusPath"
