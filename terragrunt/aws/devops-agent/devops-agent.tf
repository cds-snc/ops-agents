locals {
  # Tags applied to every IAM resource of a given Agent Space.
  agent_space_tags = {
    for key, space in var.agent_spaces : key => merge(
      var.default_tags,
      space.tags,
      { AgentSpace = key }
    )
  }
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
    iam = {
      operator_app_role_arn = aws_iam_role.operator[each.key].arn
    }
  }

  depends_on = [
    time_sleep.wait_for_iam_propagation
  ]
}
