resource "awscc_devopsagent_association" "monitoring_account" {
  agent_space_id = awscc_devopsagent_agent_space.this.agent_space_id

  association_type = "AWS"

  configuration = {
    account_id  = data.aws_caller_identity.current.account_id
    role_arn    = aws_iam_role.devops_agent.arn
    source_type = "MONITOR"
  }

  depends_on = [
    awscc_devopsagent_agent_space.this
  ]
}