output "agent_space_id" {
  description = "AWS DevOps Agent Space ID."
  value       = awscc_devopsagent_agent_space.this.agent_space_id
}

output "agent_space_arn" {
  description = "AWS DevOps Agent Space ARN."
  value       = awscc_devopsagent_agent_space.this.arn
}

output "agent_space_name" {
  description = "AWS DevOps Agent Space name."
  value       = var.agent_space_name
}

output "devops_agent_role_arn" {
  description = "IAM role assumed by AWS DevOps Agent."
  value       = aws_iam_role.devops_agent.arn
}

output "operator_role_arn" {
  description = "Operator web application IAM role."
  value       = aws_iam_role.operator.arn
}

output "monitoring_account_id" {
  description = "AWS monitoring account ID."
  value       = data.aws_caller_identity.current.account_id
}