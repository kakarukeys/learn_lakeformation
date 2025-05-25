variable "region" {
  type        = string
  description = "Region to work on."
  default     = "us-east-1"
}

variable "env" {
  type        = string
  description = "Stage to work on (dev/stg/prod)."
  default     = "dev"
}
