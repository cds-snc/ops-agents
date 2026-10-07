locals {
  # Tags applied to every IAM resource of a given Agent Space.
  agent_space_tags = {
    for key, space in var.agent_spaces : key => merge(
      var.default_tags,
      space.tags,
      { AgentSpace = key }
    )
  }

  # Agent Spaces whose web app signs in through IAM Identity Center.
  idc_space_keys = toset([for key, space in var.agent_spaces : key if space.identity_center_enabled])
}

# Depends on every instance of the IAM resources, so adding a new Agent Space
# creates a new sleep that waits for that space's roles to propagate.
resource "time_sleep" "wait_for_iam_propagation" {
  for_each = var.agent_spaces

  create_duration = "30s"

  depends_on = [
    aws_iam_role_policy_attachment.devops_agent_access,
    aws_iam_role_policy_attachment.operator_access,
    aws_iam_role_policy.resource_explorer_service_linked_role
  ]
}

resource "awscc_devopsagent_agent_space" "this" {
  for_each = var.agent_spaces

  name        = each.value.name
  description = each.value.description

  operator_app = {
    # IAM sign-in stays enabled as short (30 minute) administrator access.
    iam = {
      operator_app_role_arn = aws_iam_role.operator[each.key].arn
    }

    # Identity Center sign-in. AWS DevOps Agent creates an Identity Center
    # application for the space; groups are assigned to it in the landing zone
    # repository.
    idc = contains(local.idc_space_keys, each.key) ? {
      idc_instance_arn      = var.identity_center_instance_arn
      operator_app_role_arn = aws_iam_role.operator[each.key].arn
    } : null
  }

  depends_on = [
    time_sleep.wait_for_iam_propagation
  ]

  lifecycle {
    precondition {
      condition     = !contains(local.idc_space_keys, each.key) || var.identity_center_instance_arn != null
      error_message = "This Agent Space sets identity_center_enabled, so identity_center_instance_arn must be set."
    }
  }
}
