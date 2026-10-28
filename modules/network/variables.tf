variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach HTTPS ingress. Must not be 0.0.0.0/0 in prod."
  type        = list(string)
  default     = ["10.0.0.0/8"]
  validation {
    condition     = length(var.allowed_ingress_cidrs) > 0
    error_message = "At least one ingress CIDR must be specified."
  }
}

variable "flow_log_role_arn" {
  description = "IAM role ARN for VPC flow log delivery"
  type        = string
}

variable "flow_log_destination_arn" {
  description = "CloudWatch log group or S3 bucket ARN for flow logs"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
