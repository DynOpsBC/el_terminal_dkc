# Sprint H Decisions

## Branch Protection

Use protected `main` and `release/v1.x` branches. Require pull request review, green CI, no direct pushes, and signed release tags for RC and GA.

## Certificate Pinning

Certificate pinning defaults OFF for v1.0 because Business Central SaaS certificate rotation is controlled by Microsoft and can break mobile clients. Revisit configurable pinning in v1.1 for customer-managed endpoints.

## Macrobenchmark Structure

Add `android/macrobenchmark` as a Gradle test module targeting `:app`. Keep cold start and scan-throughput placeholders in source control so RC labs can fill in device-specific automation without reshaping the project.

## Contract Runner

Use Newman instead of Karate for v1.0 because the test artifact is portable for AppSource evidence, easy to run in GitHub Actions, and familiar to Business Central integration teams.

## AppSource Logo Placeholder

Keep logo and screenshots as explicit pre-submission placeholders until final production branding is approved. This avoids accidentally shipping draft imagery.

## URL Placeholder Pattern

Privacy, support, license, and documentation URLs are stored as plain text under `docs/appsource/` with clear pre-submission warnings so release managers can verify each external dependency before submission.
