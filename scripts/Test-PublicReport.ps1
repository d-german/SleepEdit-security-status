[CmdletBinding()]
param(
    [Parameter()]
    [string]$SiteRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")),

    [switch]$RequireMainReport
)

$ErrorActionPreference = 'Stop'

function Assert-ReportHtml {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch '(?i)<!doctype html>') {
        throw "$Description is not a complete HTML document: $Path"
    }
    if ($content -notmatch 'Content-Security-Policy') {
        throw "$Description is missing its restrictive Content-Security-Policy: $Path"
    }
    if ($content -match "'unsafe-inline'") {
        throw "$Description permits unsafe inline content: $Path"
    }
    $style = [regex]::Match($content, '(?s)<style>(.*?)</style>').Groups[1].Value.Replace("`r`n", "`n")
    $declaredHash = [regex]::Match($content, "style-src 'sha256-([^']+)'").Groups[1].Value
    $actualHash = [Convert]::ToBase64String(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($style)))
    if (-not $declaredHash -or $declaredHash -ne $actualHash) {
        throw "$Description has an invalid inline stylesheet hash: $Path"
    }
    if ($content -match '(?i)raw evidence|open retained artifact|local path') {
        throw "$Description appears to expose raw scanner evidence: $Path"
    }
    if ($content -match '(?i)[a-z]:\\') {
        throw "$Description appears to expose a local filesystem path: $Path"
    }
    if ($content -match '(?i)href=["'']\s*(?:javascript|data):') {
        throw "$Description contains an unsafe link target: $Path"
    }
}

$resolvedRoot = (Resolve-Path -LiteralPath $SiteRoot).Path
$indexPath = Join-Path $resolvedRoot 'index.html'
$reportsPath = Join-Path $resolvedRoot 'reports'
$trendPath = Join-Path $resolvedRoot 'trend/index.html'
$architecturePath = Join-Path $resolvedRoot 'architecture/index.html'
$architectureDiagramsPath = Join-Path $resolvedRoot 'architecture/diagrams'
$reviewMarkdownPath = Join-Path $resolvedRoot 'it-security-review/IT-Security-Review.md'
$reviewPath = Join-Path $resolvedRoot 'it-security-review/index.html'
$historyPath = Join-Path $resolvedRoot 'data/main-metrics-history.json'

if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw "The public report index is missing: $indexPath"
}

Assert-ReportHtml -Path $indexPath -Description 'The public report index'

if (-not (Test-Path -LiteralPath $trendPath -PathType Leaf)) {
    throw "The public metrics trend page is missing: $trendPath"
}

Assert-ReportHtml -Path $trendPath -Description 'The public metrics trend page'

if (-not (Test-Path -LiteralPath $architecturePath -PathType Leaf)) {
    throw "The architecture page is missing: $architecturePath"
}

Assert-ReportHtml -Path $architecturePath -Description 'The architecture page'
$architectureContent = Get-Content -LiteralPath $architecturePath -Raw
if ($architectureContent -notmatch 'it-security-review/index\.html') {
    throw 'The architecture page does not link to the IT and security review guide.'
}
$expectedArchitectureDiagrams = @(
    'sleepedit-system-architecture.svg',
    'sleepedit-sleep-note-authoring.svg',
    'sleepedit-medication-tool.svg',
    'sleepedit-protocol-viewer.svg',
    'sleepedit-ai-assistant.svg',
    'sleepedit-protocol-administration.svg',
    'sleepedit-administration-settings.svg',
    'sleepedit-desktop-setup.svg'
)

foreach ($diagramName in $expectedArchitectureDiagrams) {
    $diagramPath = Join-Path $architectureDiagramsPath $diagramName
    if (-not (Test-Path -LiteralPath $diagramPath -PathType Leaf)) {
        throw "An architecture diagram is missing: $diagramPath"
    }
    if ($architectureContent -notmatch [regex]::Escape("diagrams/$diagramName")) {
        throw "The architecture page does not reference $diagramName."
    }

    $diagramContent = Get-Content -LiteralPath $diagramPath -Raw
    try {
        [xml]$diagramXml = $diagramContent
    }
    catch {
        throw "An architecture diagram is not valid SVG XML: $diagramPath"
    }
    if ($diagramXml.DocumentElement.LocalName -ne 'svg') {
        throw "An architecture diagram does not have an SVG root: $diagramPath"
    }
    if ($diagramContent -match '(?i)<\?plantuml|plantuml-src|\sdata-[\w:.-]+=') {
        throw "An architecture diagram contains PlantUML metadata: $diagramPath"
    }
}

if (-not (Test-Path -LiteralPath $reviewMarkdownPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) {
    throw 'The public IT and security review Markdown or rendered page is missing.'
}

Assert-ReportHtml -Path $reviewPath -Description 'The public IT and security review guide'
$reviewMarkdown = Get-Content -LiteralPath $reviewMarkdownPath -Raw
$reviewContent = Get-Content -LiteralPath $reviewPath -Raw
if ($reviewMarkdown -notmatch '^# SleepEdit IT & Security Review Guide' -or
    $reviewContent -notmatch 'SleepEdit IT &amp; Security Review Guide' -or
    $reviewContent -notmatch 'api\.openai\.com' -or
    $reviewContent -match 'Gaps likely to be raised by hospital IT') {
    throw 'The public IT and security review guide is incomplete or contains private gap content.'
}
if ($reviewMarkdown -match '(?i)Verified from|[a-z]:\\|AdminAccess__Password\s*[=:]\s*\S+') {
    throw 'The public IT and security review Markdown exposes private evidence or a local secret boundary.'
}

$temporaryReview = Join-Path ([System.IO.Path]::GetTempPath()) "sleepedit-it-security-review-$PID.html"
try {
    & (Join-Path $PSScriptRoot 'Convert-ItSecurityReview.ps1') `
        -SourcePath $reviewMarkdownPath `
        -OutputPath $temporaryReview
    if ((Get-Content -LiteralPath $temporaryReview -Raw) -cne $reviewContent) {
        throw 'The rendered IT and security review is stale. Run scripts/Convert-ItSecurityReview.ps1.'
    }
}
finally {
    Remove-Item -LiteralPath $temporaryReview -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $historyPath -PathType Leaf) {
    $history = Get-Content -LiteralPath $historyPath -Raw | ConvertFrom-Json
    if ($history.schemaVersion -ne 1 -or $null -eq $history.snapshots) {
        throw "The public metrics history has an unsupported schema: $historyPath"
    }

    $snapshots = @($history.snapshots)
    if (@($snapshots | Where-Object { $_.branch -ne 'main' }).Count -gt 0) {
        throw "The public metrics history contains a non-main snapshot: $historyPath"
    }
    if (@($snapshots.commit | Sort-Object -Unique).Count -ne $snapshots.Count) {
        throw "The public metrics history contains duplicate commits: $historyPath"
    }

    $historyContent = Get-Content -LiteralPath $historyPath -Raw
    if ($historyContent -match '(?i)review this credential|raw evidence|[a-z]:\\') {
        throw "The public metrics history appears to expose raw scanner evidence: $historyPath"
    }
}

$reportFiles = @(Get-ChildItem -LiteralPath $reportsPath -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'index.html' } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })

if ($RequireMainReport -and -not ($reportFiles | Where-Object { $_ -match '[\\/]main[\\/]index\.html$' })) {
    throw 'The public report site must contain reports/main/index.html.'
}

foreach ($reportPath in $reportFiles) {
    Assert-ReportHtml -Path $reportPath -Description 'A public branch report'
    $content = Get-Content -LiteralPath $reportPath -Raw
    if ($content -notmatch 'sleepedit-report-branch' -or $content -notmatch 'sleepedit-report-state') {
        throw "A public branch report is missing required branch metadata: $reportPath"
    }
}

Write-Host "Validated $($reportFiles.Count) public report(s), the IT and security review, the report index, the metrics trend page, and $($expectedArchitectureDiagrams.Count) architecture diagrams."
