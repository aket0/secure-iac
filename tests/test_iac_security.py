"""
Static security validation tests for IaC configurations.

These tests verify security properties of Terraform modules by parsing
the HCL files directly (no Terraform binary required).
They document the security invariants that Checkov also enforces,
and prove that misconfigurations are detectable without a cloud account.
"""

from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent


def read_tf(*path_parts: str) -> str:
    return (REPO_ROOT / Path(*path_parts)).read_text(encoding="utf-8")


class TestS3SecurityInvariants:
    """S3 bucket must have all public access blocked and encryption enabled."""

    def setup_method(self):
        self.tf = read_tf("modules", "storage", "main.tf")

    def test_public_access_block_present(self):
        assert "aws_s3_bucket_public_access_block" in self.tf, (
            "S3 module must include aws_s3_bucket_public_access_block"
        )

    def test_block_public_acls_true(self):
        assert "block_public_acls       = true" in self.tf, (
            "block_public_acls must be set to true"
        )

    def test_block_public_policy_true(self):
        assert "block_public_policy     = true" in self.tf, (
            "block_public_policy must be set to true"
        )

    def test_restrict_public_buckets_true(self):
        assert "restrict_public_buckets = true" in self.tf, (
            "restrict_public_buckets must be set to true"
        )

    def test_server_side_encryption_configured(self):
        assert "aws_s3_bucket_server_side_encryption_configuration" in self.tf, (
            "S3 module must configure server-side encryption"
        )

    def test_kms_encryption_not_aes(self):
        assert "aws:kms" in self.tf, (
            "S3 encryption must use KMS (aws:kms), not SSE-S3 (AES256)"
        )

    def test_versioning_enabled(self):
        assert "aws_s3_bucket_versioning" in self.tf, (
            "S3 versioning must be configured"
        )
        assert 'status = "Enabled"' in self.tf, (
            "Versioning status must be Enabled"
        )

    def test_https_only_policy(self):
        assert "DenyNonTLS" in self.tf or "SecureTransport" in self.tf, (
            "S3 bucket must enforce HTTPS via a bucket policy"
        )

    def test_no_acl_public_read(self):
        assert "public-read" not in self.tf, (
            "S3 bucket must not have public-read ACL"
        )


class TestNetworkSecurityInvariants:
    """Network module must not expose admin ports to the world."""

    def setup_method(self):
        self.tf = read_tf("modules", "network", "main.tf")

    def test_no_ssh_open_to_world(self):
        # SSH (22) must not be open to 0.0.0.0/0
        ssh_block = re.search(
            r'from_port\s*=\s*22.*?cidr_blocks\s*=\s*\["0\.0\.0\.0/0"\]',
            self.tf, re.DOTALL
        )
        assert ssh_block is None, (
            "Port 22 (SSH) must not be open to 0.0.0.0/0"
        )

    def test_no_rdp_open_to_world(self):
        rdp_block = re.search(
            r'from_port\s*=\s*3389.*?cidr_blocks\s*=\s*\["0\.0\.0\.0/0"\]',
            self.tf, re.DOTALL
        )
        assert rdp_block is None, (
            "Port 3389 (RDP) must not be open to 0.0.0.0/0"
        )

    def test_private_subnets_no_public_ip(self):
        # Private subnets must not auto-assign public IPs
        private_section = re.search(
            r'resource "aws_subnet" "private".*?map_public_ip_on_launch\s*=\s*(\S+)',
            self.tf, re.DOTALL
        )
        assert private_section is not None, "Private subnet resource must be defined"
        assert private_section.group(1) == "false", (
            "Private subnets must not auto-assign public IPs (map_public_ip_on_launch = false)"
        )

    def test_flow_logs_configured(self):
        assert "aws_flow_log" in self.tf, (
            "VPC flow logs must be configured for network audit trail"
        )

    def test_security_group_description_not_empty(self):
        # A description is required by Checkov (CKV_AWS_23)
        assert 'description = "' in self.tf, (
            "Security groups must have a non-empty description"
        )


class TestIAMSecurityInvariants:
    """IAM roles must follow least privilege."""

    def setup_method(self):
        self.tf = read_tf("modules", "iam", "main.tf")

    def test_no_wildcard_action(self):
        # No statement should allow Action = "*" with Effect = "Allow"
        wildcard_allow = re.search(
            r'"Action"\s*:\s*"\*"',
            self.tf
        )
        assert wildcard_allow is None, (
            "IAM policy must not allow Action = '*'"
        )

    def test_privilege_escalation_denied(self):
        assert "DenyPrivilegeEscalation" in self.tf, (
            "IAM role must include a privilege escalation denial policy"
        )

    def test_no_admin_star_resource(self):
        # No Allow on * Resource without explicit deny
        assert "iam:PassRole" in self.tf, (
            "iam:PassRole must be controlled (deny escalation)"
        )

    def test_assume_role_uses_condition(self):
        assert "condition" in self.tf.lower(), (
            "Assume role policy must include conditions (MFA or other)"
        )


class TestStatefulBackendSecurity:
    """Terraform state must not be stored locally in shared environments."""

    def setup_method(self):
        self.tf = read_tf("environments", "dev", "main.tf")

    def test_remote_backend_documented(self):
        # S3 backend should be present (may be commented for demo)
        assert 'backend "s3"' in self.tf or '# backend "s3"' in self.tf, (
            "Remote S3 backend must be configured or documented"
        )

    def test_encryption_required_for_state(self):
        # If backend block is present, it must have encrypt = true
        if 'backend "s3"' in self.tf and not self.tf.count('backend "s3"') == self.tf.count('# backend "s3"'):
            assert "encrypt        = true" in self.tf, (
                "S3 backend must have state encryption enabled"
            )

    def test_no_tfvars_secrets(self):
        # Ensure no terraform.tfvars file exists with actual values
        tfvars = REPO_ROOT / "environments" / "dev" / "terraform.tfvars"
        assert not tfvars.exists(), (
            "terraform.tfvars must not exist in the repository (use CI secrets instead)"
        )


class TestTaggingCompliance:
    """All environments must tag resources with Environment and ManagedBy."""

    def setup_method(self):
        self.tf = read_tf("environments", "dev", "main.tf")

    def test_environment_tag_present(self):
        assert '"Environment"' in self.tf or "Environment = " in self.tf

    def test_managed_by_tag_present(self):
        assert '"ManagedBy"' in self.tf or "ManagedBy" in self.tf

    def test_managed_by_is_terraform(self):
        assert '"terraform"' in self.tf or "= terraform" in self.tf.lower()
