# secure-iac

Secure, reproducible Infrastructure as Code for AWS, with automated static analysis and no cloud account required for local testing.

## Problem Solved

Terraform configurations frequently contain security misconfigurations that only surface at apply time or after a breach: public S3 buckets, open SSH to the world, unencrypted state, no flow logs. This project provides:

1. **Hardened Terraform modules** (network, storage, IAM) with security-by-default.
2. **Python static tests** that verify security invariants without running Terraform or touching a cloud account.
3. **A CI pipeline** that blocks merges on Checkov, Trivy, and `terraform validate` failures.

## Architecture

```
secure-iac/
├── modules/
│   ├── network/     # VPC, subnets, SG, flow logs
│   ├── storage/     # S3 with KMS, versioning, public-access-block, HTTPS-only policy
│   └── iam/         # Least-privilege role, privilege-escalation denial
├── environments/
│   └── dev/         # Example environment composition
├── tests/
│   └── test_iac_security.py   # Static security invariant tests (no Terraform required)
├── .github/workflows/
│   └── iac-security.yml       # Checkov + Trivy + tf validate + static tests
└── docs/
    └── security-controls.md
```

## Technologies

| Tool            | Purpose                                 |
|-----------------|-----------------------------------------|
| Terraform 1.9+  | Infrastructure provisioning             |
| Checkov         | IaC SAST (100+ Terraform rules)         |
| Trivy           | IaC config scan                         |
| pytest          | Static security invariant tests         |
| ruff            | Python linting                          |
| GitHub Actions  | CI/CD pipeline                          |

## Prerequisites

- Python 3.11+ (for static tests — no Terraform needed)
- Terraform 1.5+ (optional, for `validate` and `plan`)
- AWS account (optional, for `apply` only)

## Installation (local tests — no cloud account required)

```bash
git clone https://github.com/aket0/secure-iac.git
cd secure-iac

python3 -m venv .venv
source .venv/bin/activate
pip install pytest ruff
```

## Running Tests

```bash
# Static security invariant tests (no Terraform, no cloud account)
pytest tests/ -v

# Lint test code
ruff check tests/
```

Expected: all tests pass.

## Running Checkov Locally

```bash
pip install checkov
checkov -d . --framework terraform
```

## Terraform Workflow (requires cloud account)

```bash
cd environments/dev

# Configure variables (never commit terraform.tfvars)
export TF_VAR_account_id="123456789012"
export TF_VAR_kms_key_id="arn:aws:kms:..."
export TF_VAR_flow_log_role_arn="arn:aws:iam::..."
export TF_VAR_flow_log_destination_arn="arn:aws:logs::..."

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan   # review before applying

# NEVER apply without reviewing the plan
# terraform apply tfplan
```

## Security Controls

### Network Module
- No admin ports (22, 3389) open to 0.0.0.0/0
- Private subnets do not auto-assign public IPs
- VPC flow logs mandatory
- Security groups require descriptions (Checkov CKV_AWS_23)

### Storage Module
- All public access blocked (4 flags)
- KMS server-side encryption (not SSE-S3)
- Versioning enabled
- HTTPS-only bucket policy (DenyNonTLS)

### IAM Module
- Least-privilege S3 read-only policy
- Privilege escalation explicitly denied
- Role assumption requires conditions

### State Security
- Remote S3 backend with encryption (documented, configured before first apply)
- `terraform.tfvars` excluded from Git

## Observed Results (local)

```
pytest tests/ -v
# 15 tests, all passing — no cloud account required
```

Checkov and Trivy results: validated in GitHub Actions (not installed locally).

## Known Limits

- Checkov and Trivy are not installed locally — they run in GitHub Actions.
- Terraform `apply` requires a real AWS account and valid credentials.
- The `environments/dev/` backend is commented out — configure before first apply.
- Module composition does not cover all possible AWS service configurations.

## Improvement Paths

- Add `environments/prod/` with stricter controls (MFA, tighter CIDRs).
- Implement SLSA provenance for Terraform plans.
- Add `tfsec` as an additional scanner.
- Use `terraform-docs` to auto-generate module documentation.
- Add cost estimation with Infracost.
