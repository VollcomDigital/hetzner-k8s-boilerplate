# Security Policy

## Supported Versions

This project currently supports security fixes for the latest version on the `main` branch.

| Version | Supported |
| ------- | --------- |
| main    | :white_check_mark: |
| older branches/tags | :x: |

## Reporting a Vulnerability

Please do **not** open public GitHub issues for security vulnerabilities.

To report a vulnerability:

1. Open a **private security advisory** in this repository:
   `Security` -> `Advisories` -> `Report a vulnerability`
2. Include:
   - Affected component/files
   - Reproduction steps or proof-of-concept
   - Impact assessment
   - Suggested remediation (if available)

### Response Targets

- Initial triage acknowledgement: within 3 business days
- Impact assessment and mitigation plan: within 7 business days
- Patch and coordinated disclosure timeline: shared after triage

## Scope

Security reports are in scope for:

- Terraform modules and infrastructure definitions
- Kubernetes manifests and Helm values in this repository
- Shell automation scripts
- GitHub Actions workflows and CI/CD configuration
