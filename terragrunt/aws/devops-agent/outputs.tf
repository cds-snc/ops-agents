output "agent_spaces" {
  description = "Created AWS DevOps Agent Spaces, keyed by team identifier."
  value = {
    for key, space in awscc_devopsagent_agent_space.this : key => {
      id                    = space.agent_space_id
      arn                   = space.arn
      name                  = space.name
      devops_agent_role_arn = aws_iam_role.devops_agent[key].arn
      operator_role_arn     = aws_iam_role.operator[key].arn
    }
  }
}

output "monitoring_account_id" {
  description = "AWS monitoring account ID."
  value       = data.aws_caller_identity.current.account_id
}
