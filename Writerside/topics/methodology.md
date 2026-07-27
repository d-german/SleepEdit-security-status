# Methodology and disclosure

SleepEdit runs independent checks on the private source repository for every change proposed to the main branch and every production-bound push to main.

The release workflow includes:

- Microsoft .NET security analyzers during a warning-as-error release build.
- SonarQube Community Build source analysis and quality metrics.
- Direct and transitive NuGet vulnerability auditing.
- npm vulnerability auditing against the committed lock file.
- Automated .NET tests with OpenCover-compatible coverage collection.

After all release jobs succeed, a strict transformation script creates a small public JSON document. The GitHub App can write only to this public status repository. It receives a short-lived installation token during the workflow; its private key is stored only as an encrypted Actions secret in the private repository.

## Information intentionally not published

The public report excludes source code, repository paths, finding messages, rule-level locations, dependency names associated with unresolved findings, secrets, raw scanner exports, stack traces, and risk-acceptance justifications. Complete evidence is retained as private workflow artifacts for 90 days.

## Interpretation

A passing report means the configured controls passed for the identified commit at the stated time. It does not certify that the software is vulnerability-free and does not replace penetration testing or customer security review.
