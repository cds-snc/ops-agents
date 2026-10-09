resource "awscc_devopsagent_association" "monitoring_account" {
  for_each = var.agent_spaces

  agent_space_id = awscc_devopsagent_agent_space.this[each.key].agent_space_id
  service_id     = "aws"

  configuration = {
    aws = {
      account_id         = data.aws_caller_identity.current.account_id
      account_type       = "monitor"
      assumable_role_arn = aws_iam_role.devops_agent[each.key].arn
    }
  }
}

locals {
  # One entry per (Agent Space, secondary account) pair, keyed "<team>/<account_id>".
  # Keys only use values from the YAML files, so adding or removing an account only
  # touches that account's association.
  source_account_associations = {
    for pair in flatten([
      for key, space in var.agent_spaces : [
        for account_id in space.source_accounts : {
          space      = key
          account_id = account_id
          role_arn   = "arn:${data.aws_partition.current.partition}:iam::${account_id}:role/${var.source_account_role_name}"
        }
      ]
    ]) : "${pair.space}/${pair.account_id}" => pair
  }
}

# Secondary (source) accounts the Agent Space investigates. The role in each account
# (var.source_account_role_name) is created outside this repository, in
# aft-account-customizations and aft-account-request with the devops_agent_space_arn
# flag. Its trust policy allows aidevops.amazonaws.com with aws:SourceAccount set to
# this monitoring account and aws:SourceArn matching the Agent Space ARN.
resource "awscc_devopsagent_association" "source_account" {
  for_each = local.source_account_associations

  agent_space_id = awscc_devopsagent_agent_space.this[each.value.space].agent_space_id
  service_id     = "aws"

  configuration = {
    source_aws = {
      account_id         = each.value.account_id
      account_type       = "source"
      assumable_role_arn = each.value.role_arn
    }
  }

  depends_on = [awscc_devopsagent_association.monitoring_account]
}
