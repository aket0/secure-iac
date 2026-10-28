variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "account_id" {
  description = "AWS account ID (used for globally unique bucket names)"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for S3 encryption"
  type        = string
}

variable "flow_log_role_arn" {
  description = "IAM role ARN for VPC flow log delivery"
  type        = string
}

variable "flow_log_destination_arn" {
  description = "CloudWatch log group ARN for flow logs"
  type        = string
}
