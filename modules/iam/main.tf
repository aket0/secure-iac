# IAM module — roles and policies with least-privilege

# Application role: only what is needed to run
resource "aws_iam_role" "app" {
  name               = "${var.environment}-app-role"
  description        = "Application role — least-privilege access"
  assume_role_policy = data.aws_iam_policy_document.app_assume.json

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

data "aws_iam_policy_document" "app_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = var.trusted_services
    }

    # Condition: require MFA or specific conditions for sensitive services
    dynamic "condition" {
      for_each = var.require_mfa ? [1] : []
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }
  }
}

# Read-only policy for S3 — no write unless explicitly granted
resource "aws_iam_role_policy" "app_s3_read" {
  name = "${var.environment}-app-s3-read"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadOnly"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.allowed_bucket}",
          "arn:aws:s3:::${var.allowed_bucket}/*",
        ]
      }
    ]
  })
}

# Deny privilege escalation: cannot attach policies to themselves
resource "aws_iam_role_policy" "deny_privilege_escalation" {
  name = "${var.environment}-deny-privilege-escalation"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPrivilegeEscalation"
        Effect = "Deny"
        Action = [
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:CreatePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:PassRole",
        ]
        Resource = "*"
      }
    ]
  })
}
