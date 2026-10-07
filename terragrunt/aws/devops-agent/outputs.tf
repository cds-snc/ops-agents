output "agent_spaces" {
  description = "Created AWS DevOps Agent Spaces, keyed by team identifier."
  value = {
    for key, space in awscc_devopsagent_agent_space.this : key => {
      id                    = space.agent_space_id
      arn                   = space.arn
      name                  = space.name
      devops_agent_role_arn = aws_iam_role.devops_agent[key].arn
      operator_role_arn     = aws_iam_role.operator[key].arn

      # Null when the space does not use Identity Center.
      identity_center_application_arn = contains(local.idc_space_keys, key) ? space.operator_app.idc.idc_application_arn : null

      # The ARN looks like arn:aws:sso::<account>:application/ssoins-xxxx/apl-xxxx.
      # The application ID is the last part, apl-xxxx. The ARN is null until AWS
      # has created the application, for example during the plan that first
      # enables Identity Center, so fall back to null instead of failing.
      identity_center_application_id = try(element(split("/", space.operator_app.idc.idc_application_arn), 2), null)
    }
  }
}

output "monitoring_account_id" {
  description = "AWS monitoring account ID."
  value       = data.aws_caller_identity.current.account_id
}
