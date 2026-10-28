variable "environment" {
  description = "Environment name"
  type        = string
}

variable "trusted_services" {
  description = "AWS services allowed to assume this role (e.g. ec2.amazonaws.com)"
  type        = list(string)
  default     = ["ec2.amazonaws.com"]
}

variable "require_mfa" {
  description = "Require MFA for role assumption"
  type        = bool
  default     = false
}

variable "allowed_bucket" {
  description = "S3 bucket name the app role may read"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
