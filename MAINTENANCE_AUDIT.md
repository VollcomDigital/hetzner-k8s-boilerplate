# Maintenance Audit Report

**Repository:** Hetzner Kubernetes Boilerplate
**Date:** 2026-02-22
**Auditor:** Cursor AI (DevSecOps Routine Maintenance)

---

### Dependency Management with Dependabot

**Status: Fail**

The repository uses **Renovate** (`renovate.json`) instead of GitHub's native Dependabot. While Renovate is a valid and feature-rich alternative, there is no `.github/dependabot.yml` file present. The Renovate configuration covers Terraform providers, GitHub Actions, Kubernetes manifests, and custom regex managers for k3s/Cilium CLI versions.

- [ ] Add `.github/dependabot.yml` as a complementary layer, or document in the README that Renovate is the chosen dependency management tool and Dependabot is intentionally omitted
- [ ] Pin `aquasecurity/trivy-action@master` in `validate.yml` to a tagged release or commit SHA — using `@master` is a supply-chain risk and bypasses Renovate/Dependabot tracking
- [ ] Pin GitHub Actions to full commit SHAs instead of major version tags (e.g., `actions/checkout@v4` should be `actions/checkout@<sha>`) to prevent tag-mutation supply-chain attacks
- [ ] Add a Renovate `postUpdateOptions` or `packageRule` to auto-pin GitHub Actions to SHA digests

### Vulnerability Alerts with GitHub Security

**Status: Fail**

The repository has a Trivy security scan in CI (`validate.yml`) but it is configured with `exit-code: 0`, meaning the pipeline will **never fail** on HIGH/CRITICAL vulnerabilities. There is no `SECURITY.md` policy file at the repository root. No CodeQL or Dependabot security alert workflows are configured.

- [ ] Create a `SECURITY.md` file at the repository root with a vulnerability disclosure policy (responsible disclosure contacts, supported versions, reporting process)
- [ ] Change `exit-code: 0` to `exit-code: 1` in the Trivy scan steps in `.github/workflows/validate.yml` so the CI pipeline fails on HIGH/CRITICAL findings
- [ ] Add a CodeQL analysis workflow (`.github/workflows/codeql.yml`) or enable GitHub Advanced Security for automated vulnerability detection
- [ ] Consider adding `gitleaks` or `trufflehog` as a CI step for secret scanning in pull requests
- [ ] Add a `CODEOWNERS` file to ensure security-sensitive paths (terraform/, kubernetes/security/) require review from designated maintainers

### Security Risk Monitoring with SonarQube Cloud

**Status: Fail**

There is no `sonar-project.properties` file in the repository root. No SonarQube or SonarCloud integration steps exist in any CI/CD workflow.

- [ ] Add SonarQube Cloud integration by creating a `sonar-project.properties` file and adding a SonarCloud scan step to the CI pipeline
- [ ] Alternatively, if SonarQube is not desired, document the decision and identify the equivalent static analysis tools in use (currently only Trivy for config scanning)

### AI-Powered Threat Detection with Cursor AI

**Status: Needs Manual Check**

Static analysis of the codebase identified the following potential security concerns:

- [ ] **Kubeconfig file permissions too permissive:** `write-kubeconfig-mode: "0644"` in `terraform/cloud-init/control-plane.yaml.tftpl` makes the kubeconfig world-readable on the node — change to `"0600"` to restrict access to root only
- [ ] **Privileged container in etcd-snapshot CronJob:** `kubernetes/backup/etcd-snapshot.yaml` runs with `privileged: true` and `hostNetwork: true` — document why this is required (etcd access) and add a comment noting the security implications; consider if a more restrictive `securityContext` with specific capabilities is feasible
- [ ] **Hardcoded placeholder credentials in documentation/examples:** `terraform/terraform.tfvars.example`, `docs/components/authentication.md`, `terraform/modules/dns/README.md`, and `kubernetes/system/dex/README.md` contain placeholder tokens like `YOUR_HCLOUD_API_TOKEN` and `your-client-secret` — verify these files are clearly marked as examples and that `.gitignore` prevents real `terraform.tfvars` from being committed (confirmed: `terraform.tfvars` is in `.gitignore`)
- [ ] **Cloud-init templates pipe curl to shell:** `terraform/cloud-init/control-plane.yaml.tftpl` and `worker.yaml.tftpl` use `curl | sh` to install k3s — pin the k3s install script checksum or use a verified download mechanism
- [ ] **Cilium CLI version fetched dynamically at deploy time:** The control-plane cloud-init fetches the latest Cilium CLI version from GitHub at runtime — pin this to a specific version for reproducibility and to avoid supply-chain compromise
- [ ] **No `eval()` usage found** — Pass
- [ ] **No hardcoded AWS access keys found** — Pass
- [ ] **No SQL/NoSQL injection vectors found** — Pass (infrastructure-only repo, no application code)
- [ ] **No XSS vectors found** — Pass (no web application code)

### Compliance and Best Practices Review

**Status: Needs Manual Check**

| File | Status |
|------|--------|
| `README.md` | Present, comprehensive |
| `LICENSE` | Present (MIT) |
| `.gitignore` | Present, well-structured |
| `CONTRIBUTING.md` | Present, detailed |
| `.editorconfig` | **Missing** |
| `SECURITY.md` | **Missing** |
| `CODEOWNERS` | **Missing** |
| `.pre-commit-config.yaml` | **Missing** |

- [ ] Add an `.editorconfig` file to enforce consistent formatting (indent style, trailing whitespace, end-of-line) across editors and contributors
- [ ] Add a `.pre-commit-config.yaml` with hooks for `terraform fmt`, `terraform validate`, `yamllint`, `shellcheck`, and `detect-secrets` to catch issues before they reach CI
- [ ] Add a `CODEOWNERS` file to define required reviewers for critical paths (`terraform/`, `kubernetes/security/`, `.github/workflows/`)
- [ ] Add YAML linting (e.g., `yamllint`) to the CI pipeline for Kubernetes manifests — currently only `kubeconform` validates schema but not style
- [ ] Add `shellcheck` linting for all scripts in `scripts/` to the CI pipeline — scripts follow best practices (`set -euo pipefail`) but are not statically analyzed in CI
- [ ] The Terraform remote backend configuration is commented out in `terraform/versions.tf` — document whether this is intentional for the boilerplate or add a TODO for users to configure it
- [ ] Consider adding a `CHANGELOG.md` or adopting automated changelog generation (e.g., `release-please`) tied to the semantic commit convention already in use
- [ ] The `deploy-app.yml` workflow references an `app/` directory that does not exist in the repository — mark this clearly as a template or move it to a separate `examples/` directory to avoid confusion
