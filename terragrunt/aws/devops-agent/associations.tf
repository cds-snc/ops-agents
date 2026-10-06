resource "awscc_devopsagent_association" "monitoring_account" {
  agent_space_id = awscc_devopsagent_agent_space.this.agent_space_id
  service_id     = "aws"

  configuration = {
    aws = {
      account_id         = data.aws_caller_identity.current.account_id
      account_type       = "monitor"
      assumable_role_arn = aws_iam_role.devops_agent.arn
    }
  }

  depends_on = [
    awscc_devopsagent_agent_space.this
  ]
}