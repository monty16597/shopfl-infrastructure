variable "name" {
  description = "Full Lambda function name, e.g. shopfl-order-dev-create-order."
  type        = string
}

variable "handler" {
  description = "Lambda handler string, e.g. handlers.create_order.handler."
  type        = string
}

variable "artifact_path" {
  description = "Path to the deployment package zip built by the owning service repository."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime identifier."
  type        = string
  default     = "python3.12"
}

variable "env_vars" {
  description = "Environment variables exported to the function."
  type        = map(string)
  default     = {}
}

variable "memory_mb" {
  description = "Function memory size in megabytes."
  type        = number
  default     = 512
}

variable "timeout_s" {
  description = "Function timeout in seconds."
  type        = number
  default     = 10
}

variable "reserved_concurrency" {
  description = "Reserved concurrent executions. -1 leaves concurrency unreserved."
  type        = number
  default     = -1
}

variable "policy_statements" {
  description = "Additional IAM statements attached to the function's inline execution policy."
  type = list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Extra tags applied to the function."
  type        = map(string)
  default     = {}
}
