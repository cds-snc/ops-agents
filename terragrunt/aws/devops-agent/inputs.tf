variable "agent_space_name" {
  description = "Name of the AWS DevOps Agent Space."
  type        = string

  validation {
    condition     = length(trimspace(var.agent_space_name)) > 2
    error_message = "The Agent Space name must contain at least three characters."
  }
}

variable "agent_space_description" {
  description = "Description of the Agent Space and its operational boundary."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["development", "test", "staging", "production"], var.environment)
    error_message = "Environment must be development, test, staging, or production."
  }
}

variable "application_name" {
  description = "Application or platform monitored by the Agent Space."
  type        = string
}