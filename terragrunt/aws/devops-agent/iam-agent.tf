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

resource "aws_iam_role" "devops_agent" {
  name_prefix        = "DevOpsAgentRole-AgentSpace-"
  description        = "Role assumed by AWS DevOps Agent for ${var.application_name}"
  assume_role_policy = data.aws_iam_policy_document.devops_agent_assume_role.json

  tags = var.default_tags
}

# Attach the AWS-managed DevOps Agent access policy
resource "aws_iam_role_policy_attachment" "devops_agent_access" {
  role       = aws_iam_role.devops_agent.name
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
  name   = "AllowResourceExplorerServiceLinkedRole"
  role   = aws_iam_role.devops_agent.id
  policy = data.aws_iam_policy_document.resource_explorer_service_linked_role.json
}