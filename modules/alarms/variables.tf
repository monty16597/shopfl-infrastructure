variable "name" {
  description = "Alarm name, shopfl-<service>-<env>-<p0|p1|p2>-<signal>."
  type        = string
}

variable "severity" {
  description = "Severity tag value: P0, P1 or P2."
  type        = string
}

variable "service" {
  description = "Service tag value."
  type        = string
}

variable "env" {
  description = "Env tag value."
  type        = string
}

variable "description" {
  description = "Alarm description carrying operational metadata."
  type        = string
}

variable "namespace" {
  description = "CloudWatch metric namespace."
  type        = string
}

variable "metric_name" {
  description = "CloudWatch metric name."
  type        = string
}

variable "dimensions" {
  description = "CloudWatch metric dimensions."
  type        = map(string)
  default     = {}
}

variable "statistic" {
  description = "Metric statistic. Leave null when extended_statistic is set."
  type        = string
  default     = "Sum"
  nullable    = true
}

variable "extended_statistic" {
  description = "Percentile statistic such as p99. Leave null when statistic is set."
  type        = string
  default     = null
  nullable    = true
}

variable "period" {
  description = "Evaluation period in seconds."
  type        = number
  default     = 300
}

variable "evaluation_periods" {
  description = "Number of periods evaluated."
  type        = number
  default     = 1
}

variable "datapoints_to_alarm" {
  description = "Datapoints that must breach within the evaluation window."
  type        = number
  default     = null
  nullable    = true
}

variable "threshold" {
  description = "Threshold the metric is compared against."
  type        = number
}

variable "comparison_operator" {
  description = "Comparison operator applied to the threshold."
  type        = string
  default     = "GreaterThanOrEqualToThreshold"
}

variable "treat_missing_data" {
  description = "How missing datapoints are treated."
  type        = string
  default     = "notBreaching"
}

variable "alarm_actions" {
  description = "Actions invoked when the alarm enters ALARM."
  type        = list(string)
}

variable "ok_actions" {
  description = "Actions invoked when the alarm returns to OK."
  type        = list(string)
}
