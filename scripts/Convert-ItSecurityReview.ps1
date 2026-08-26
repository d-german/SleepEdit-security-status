[CmdletBinding()]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\it-security-review\IT-Security-Review.md'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\it-security-review\index.html')
)

$ErrorActionPreference = 'Stop'
$markdown = Get-Content -LiteralPath $SourcePath -Raw
$content = (ConvertFrom-Markdown -InputObject $markdown).Html
$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
  <title>SleepEdit IT &amp; Security Review Guide</title>
  <style>
  :root { color-scheme:light; --navy:#020f59; --blue:#00449d; --ink:#18202b; --muted:#586577; --line:#d8dee8; --surface:#fff; --page:#f4f7fb; --soft:#eef4fb; --warning:#8a4b08; }
  * { box-sizing:border-box; }
  html { scroll-behavior:smooth; }
  body { margin:0; background:var(--page); color:var(--ink); font:16px/1.58 "Segoe UI",Arial,sans-serif; }
  a { color:var(--blue); font-weight:650; }
  main { width:min(1180px,calc(100% - 32px)); margin:24px auto 64px; }
  .site-nav { display:flex; flex-wrap:wrap; gap:8px 20px; margin:0 0 16px; padding:14px 18px; border:1px solid var(--line); border-radius:12px; background:var(--surface); }
  article { overflow:hidden; padding:34px; border:1px solid var(--line); border-top:7px solid var(--blue); border-radius:16px; background:var(--surface); box-shadow:0 4px 16px rgba(2,15,89,.06); }
  h1,h2,h3 { color:var(--navy); font-family:Georgia,"Times New Roman",serif; font-weight:500; line-height:1.2; }
  h1 { margin:0 0 8px; font-size:clamp(2.05rem,4vw,3.35rem); }
  h2 { margin:38px 0 12px; padding-top:8px; border-top:1px solid var(--line); font-size:1.55rem; scroll-margin-top:12px; }
  h3 { margin:18px 0 8px; font-size:1.08rem; }
  p,li { max-width:92ch; }
  strong { color:var(--navy); }
  code { overflow-wrap:anywhere; }
  pre { overflow:auto; padding:16px; border:1px solid var(--line); border-radius:10px; background:#f7f9fc; white-space:pre-wrap; }
  table { display:block; width:100%; overflow:auto; border:1px solid var(--line); border-radius:10px; border-collapse:collapse; }
  thead { background:var(--soft); }
  th,td { min-width:150px; padding:10px 12px; border-bottom:1px solid var(--line); text-align:left; vertical-align:top; }
  th { color:var(--navy); }
  tr:last-child td { border-bottom:0; }
  blockquote { margin:18px 0; padding:10px 16px; border-left:4px solid var(--warning); background:#fff8ed; }
  footer { padding:24px 4px; color:var(--muted); text-align:center; }
  @media (max-width:680px) { main { width:min(100% - 16px,1180px); margin-top:8px; } article { padding:22px 18px; } .site-nav { padding:12px; } }
  @media print { body { background:#fff; } main { width:100%; margin:0; } .site-nav { display:none; } article { padding:0; border:0; box-shadow:none; } a { color:inherit; } }
  </style>
</head>
<body>
<main>
  <nav class="site-nav" aria-label="Security site">
    <a href="../index.html">Security &amp; quality reports</a>
    <a href="index.html" aria-current="page">IT &amp; security review</a>
    <a href="../architecture/index.html">Architecture &amp; workflows</a>
    <a href="../trend/index.html">Security &amp; quality trend</a>
  </nav>
  <article>
$content
  </article>
  <footer>Technical review material for healthcare IT. Verify deployment-dependent and contractual statements for the evaluated environment.</footer>
</main>
</body>
</html>
"@

$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $directory -Force | Out-Null
[System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.UTF8Encoding]::new($false))
