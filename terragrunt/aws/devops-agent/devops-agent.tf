resource "time_sleep" "wait_for_iam_propagation" {
  create_duration = "30s"

  depends_on = [
    aws_iam_role_policy_attachment.devops_agent_access,
    aws_iam_role_policy_attachment.operator_access,
    aws_iam_role_policy.resource_explorer_service_linked_role
  ]
}

resource "awscc_devopsagent_agent_space" "this" {
  name        = var.agent_space_name
  description = var.agent_space_description

  operator_app = {
    enabled  = true
    role_arn = aws_iam_role.operator.arn
  }

  depends_on = [
    time_sleep.wait_for_iam_propagation
  ]
}