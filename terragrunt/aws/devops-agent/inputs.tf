variable "agent_spaces" {
  description = <<-EOT
    Map of AWS DevOps Agent Spaces to create, keyed by a short, stable team identifier
    (lowercase letters, numbers and hyphens). Each Agent Space gets its own agent IAM role,
    operator IAM role and monitoring-account association.

    Do not rename a key once applied: the key is the Terraform address of the space's
    resources, so renaming it destroys and recreates that team's Agent Space.
  EOT
  type = map(object({
    name             = string
    description      = string
    application_name = string
    tags             = optional(map(string), {})
  }))

  validation {
    condition     = length(var.agent_spaces) > 0
    error_message = "At least one Agent Space must be defined."
  }

  validation {
    condition     = alltrue([for key in keys(var.agent_spaces) : can(regex("^[a-z0-9][a-z0-9-]{0,30}$", key))])
    error_message = "Agent Space keys must be 1-31 characters of lowercase letters, numbers and hyphens, starting with a letter or number."
  }

  validation {
    condition     = alltrue([for space in values(var.agent_spaces) : length(trimspace(space.name)) > 2])
    error_message = "Each Agent Space name must contain at least three characters."
  }

  validation {
    condition     = length(distinct([for space in values(var.agent_spaces) : space.name])) == length(var.agent_spaces)
    error_message = "Agent Space names must be unique."
  }
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
