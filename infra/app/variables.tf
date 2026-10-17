variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "image_digest" {
  description = "Digest of the container image to deploy, e.g. sha256:abc..."
  type        = string

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.image_digest))
    error_message = "image_digest must look like sha256: followed by 64 hex characters."
  }
}