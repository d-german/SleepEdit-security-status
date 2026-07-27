[CmdletBinding()]
param(
    [string] $StatusPath = (Join-Path $PSScriptRoot '../data/latest.json'),
    [string] $TopicsDirectory = (Join-Path $PSScriptRoot '../Writerside/topics')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot 'Test-PublicStatusData.ps1') -StatusPath $StatusPath
$status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json

function Format-Value {
    param($Value, [string] $Suffix = '')
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'Pending' }
    return "$Value$Suffix"
}

function Format-Status {
    param([string] $Value)
    switch ($Value) {
        'passed' { 'Passed' }
        'failed' { 'Failed' }
        default { 'Pending' }
    }
}

function Format-Rating {
    param($Value)
    if ($null -eq $Value) { return 'Pending' }
    $ratings = @{ '1.0' = 'A'; '2.0' = 'B'; '3.0' = 'C'; '4.0' = 'D'; '5.0' = 'E' }
    $key = ([double]$Value).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
    if ($ratings.ContainsKey($key)) { return $ratings[$key] }
    return [string]$Value
}

New-Item -ItemType Directory -Path $TopicsDirectory -Force | Out-Null
$scanDate = if ($null -eq $status.scanDateUtc) { 'Pending' } else { ([DateTimeOffset]$status.scanDateUtc).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC') }
$commit = Format-Value $status.commit

@"
# SleepEdit security status

This site publishes sanitized results from the independent security and quality controls that run against SleepEdit's private source repository.

| Measurement | Current result |
|---|---:|
| Overall release scan | $(Format-Status $status.overall) |
| Source security analysis | $(Format-Status $status.staticAnalysis.status) |
| Dependency audit | $(Format-Status $status.dependencies.status) |
| Automated tests | $(Format-Status $status.tests.status) |
| Code coverage | $(Format-Value $status.quality.coveragePercent '%') |

Last scan: $scanDate

Commit: $commit

See [Methodology and disclosure](methodology.md) for what is published and what is intentionally withheld.
"@ | Set-Content -LiteralPath (Join-Path $TopicsDirectory 'status-overview.md') -Encoding utf8

@"
# Third-party dependency security

| Ecosystem | Total vulnerabilities | Critical | High | Moderate | Low |
|---|---:|---:|---:|---:|---:|
| NuGet | $(Format-Value $status.dependencies.nuget.total) | $(Format-Value $status.dependencies.nuget.critical) | $(Format-Value $status.dependencies.nuget.high) | $(Format-Value $status.dependencies.nuget.moderate) | $(Format-Value $status.dependencies.nuget.low) |
| npm | $(Format-Value $status.dependencies.npm.total) | $(Format-Value $status.dependencies.npm.critical) | $(Format-Value $status.dependencies.npm.high) | $(Format-Value $status.dependencies.npm.moderate) | $(Format-Value $status.dependencies.npm.low) |

Result: **$(Format-Status $status.dependencies.status)**

The release scan audits direct and transitive NuGet dependencies and the locked npm dependency graph. A successful result means the configured release gate found no high or critical dependency vulnerability at scan time; it is not a guarantee that no vulnerability exists.
"@ | Set-Content -LiteralPath (Join-Path $TopicsDirectory 'dependency-security.md') -Encoding utf8

@"
# Source security analysis

| Measurement | Current result |
|---|---:|
| SonarQube quality gate | $(Format-Status $status.staticAnalysis.qualityGate) |
| Vulnerabilities | $(Format-Value $status.staticAnalysis.vulnerabilities) |
| Security hotspots | $(Format-Value $status.staticAnalysis.securityHotspots) |
| Security hotspots reviewed | $(Format-Value $status.staticAnalysis.securityHotspotsReviewedPercent '%') |
| Documented temporary exceptions | $(Format-Value $status.staticAnalysis.documentedExceptions) |
| Security rating | $(Format-Rating $status.staticAnalysis.securityRating) |

Detailed rule identifiers, file paths, source snippets, finding messages, and exception justifications are retained privately so this public report does not become a roadmap for attacking the application.
"@ | Set-Content -LiteralPath (Join-Path $TopicsDirectory 'source-analysis.md') -Encoding utf8

@"
# Quality and testing

| Measurement | Current result |
|---|---:|
| .NET tests passed | $(Format-Value $status.tests.passed) |
| .NET tests failed | $(Format-Value $status.tests.failed) |
| Overall coverage | $(Format-Value $status.quality.coveragePercent '%') |
| Line coverage | $(Format-Value $status.quality.lineCoveragePercent '%') |
| Branch coverage | $(Format-Value $status.quality.branchCoveragePercent '%') |
| Cyclomatic complexity | $(Format-Value $status.quality.complexity) |
| Cognitive complexity | $(Format-Value $status.quality.cognitiveComplexity) |
| Duplicated lines density | $(Format-Value $status.quality.duplicatedLinesDensityPercent '%') |
| Bugs | $(Format-Value $status.quality.bugs) |
| Code smells | $(Format-Value $status.quality.codeSmells) |
| Maintainability rating | $(Format-Rating $status.quality.maintainabilityRating) |

Coverage measures executed code, not correctness. The release decision also depends on static analysis, dependency scanning, focused automated tests, and manual review.
"@ | Set-Content -LiteralPath (Join-Path $TopicsDirectory 'quality-and-testing.md') -Encoding utf8

Write-Host "Rendered Writerside status topics from $StatusPath."
