data "aws_iam_policy_document" "devops_agent_assume_role" {
  statement {
    sid     = "AllowAWSDevOpsAgent"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["aidevops.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# One agent role per Agent Space. The prefix follows the AWS DevOps Agent naming
# convention; the AgentSpace tag identifies which team the role belongs to.
resource "aws_iam_role" "devops_agent" {
  for_each = var.agent_spaces

  name_prefix        = "DevOpsAgentRole-AgentSpace-"
  description        = "Role assumed by AWS DevOps Agent for ${each.value.application_name}"
  assume_role_policy = data.aws_iam_policy_document.devops_agent_assume_role.json

  tags = local.agent_space_tags[each.key]
}

# Attach the AWS-managed DevOps Agent access policy
resource "aws_iam_role_policy_attachment" "devops_agent_access" {
  for_each = var.agent_spaces

  role       = aws_iam_role.devops_agent[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AIDevOpsAgentAccessPolicy"
}

# AWS DevOps Agent can also require permission to create or use the AWS Resource Explorer service-linked role.
# Create a narrowly scoped inline policy:
data "aws_iam_policy_document" "resource_explorer_service_linked_role" {
  statement {
    sid    = "AllowResourceExplorerServiceLinkedRole"
    effect = "Allow"

    actions = [
      "iam:CreateServiceLinkedRole"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["resource-explorer-2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "resource_explorer_service_linked_role" {
  for_each = var.agent_spaces

  name   = "AllowResourceExplorerServiceLinkedRole"
  role   = aws_iam_role.devops_agent[each.key].id
  policy = data.aws_iam_policy_document.resource_explorer_service_linked_role.json
}
