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

    # Connects the space's web app to IAM Identity Center. Groups are assigned to
    # the resulting application in the landing zone repository.
    identity_center_enabled = optional(bool, false)

    # Secondary account IDs the Agent Space can investigate. Each account must
    # already have the role named by source_account_role_name.
    source_accounts = optional(list(string), [])
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

  validation {
    condition = alltrue(flatten([
      for space in values(var.agent_spaces) : [
        for account_id in space.source_accounts : can(regex("^[0-9]{12}$", account_id))
      ]
    ]))
    error_message = "Each source account must be a 12-digit account ID, quoted in YAML."
  }

  validation {
    condition = alltrue([
      for space in values(var.agent_spaces) :
      length(distinct(space.source_accounts)) == length(space.source_accounts)
    ])
    error_message = "A source account can only be listed once per Agent Space."
  }

  validation {
    condition = alltrue(flatten([
      for space in values(var.agent_spaces) : [
        for account_id in space.source_accounts : account_id != var.account_id
      ]
    ]))
    error_message = "The monitoring account is associated automatically. Do not list it under source_accounts."
  }
}

variable "source_account_role_name" {
  description = "Name of the role AWS DevOps Agent assumes in every secondary account. It is created outside this repository."
  type        = string
  default     = "DevOpsAgentRole-AgentSpace"

  validation {
    condition     = can(regex("^[\\w+=,.@-]{1,64}$", var.source_account_role_name))
    error_message = "source_account_role_name must be a valid IAM role name."
  }
}

variable "identity_center_instance_arn" {
  description = <<-EOT
    ARN of the IAM Identity Center organization instance used for web app sign-in, for
    example arn:aws:sso:::instance/ssoins-1234567890abcdef. Required when any Agent Space
    sets identity_center_enabled. Find it under Settings in the Identity Center console
    of the management account.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.identity_center_instance_arn == null || can(regex("^arn:aws[a-z-]*:sso:::instance/(sso)?ins-[a-zA-Z0-9-.]{16}$", var.identity_center_instance_arn))
    error_message = "identity_center_instance_arn must look like arn:aws:sso:::instance/ssoins-1234567890abcdef."
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
