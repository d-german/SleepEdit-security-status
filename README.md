# SleepEdit Security and Quality Reports

This repository publishes static, detailed transparency reports for SleepEdit's `main` branch and active `feature/*` and `feat/*` branches. GitHub Pages serves the rendered reports from [`index.html`](index.html).

The source-verified system and workflow diagrams are published from [`architecture/`](architecture/index.html). The SVG files in `architecture/diagrams/` are the canonical copies mirrored to the custom-domain repository by SleepEdit's main security workflow.

The public healthcare-review FAQ is maintained in [`it-security-review/IT-Security-Review.md`](it-security-review/IT-Security-Review.md) and rendered as [`it-security-review/index.html`](it-security-review/index.html) with the repository's built-in PowerShell converter.

Each report discloses the scanned branch and commit, completed or incomplete scan state, quality-gate result, coverage, dependency findings, test totals, and SonarQube issue and hotspot details. A failed, cancelled, or incomplete scan is shown explicitly and is never presented as passing.

[`trend/index.html`](trend/index.html) records the aggregate security and quality metrics from each completed `main` scan. Snapshots are appended once per commit and contain only bounded counts, ratings, coverage, and dependency totals; they never include source text, issue messages, local paths, credentials, or raw scan artifacts.

Raw scanner JSON, XML, TRX files, source text, credentials, private paths, and private artifact links remain private in the source repository's release evidence. The publishing GitHub App is restricted to this repository and has only metadata-read and contents-write access.
