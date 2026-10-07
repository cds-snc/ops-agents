data "aws_iam_policy_document" "operator_assume_role" {
  statement {
    sid    = "AllowAWSDevOpsAgentOperatorApp"
    effect = "Allow"

    # sts:TagSession lets the web app tag the session with the AgentSpaceId, which
    # AIDevOpsOperatorAppAccessPolicy uses to scope access. It is required for both
    # IAM and Identity Center sign-in.
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["aidevops.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:aidevops:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:agentspace/*"]
    }
  }

  # Identity Center sign-in: lets the web app attach the signed-in Identity Center
  # user's identity to the session. Without it, IAM admin access works but
  # Identity Center users are refused with "not authorized to view this Agent
  # Space". Limited to Identity Center as the context provider.
  statement {
    sid     = "AllowAWSDevOpsAgentIdentityCenterContext"
    effect  = "Allow"
    actions = ["sts:SetContext"]

    principals {
      type        = "Service"
      identifiers = ["aidevops.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:aidevops:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:agentspace/*"]
    }

    condition {
      test     = "ForAllValues:ArnEquals"
      variable = "sts:RequestContextProviders"
      values   = ["arn:${data.aws_partition.current.partition}:iam::aws:contextProvider/IdentityCenter"]
    }
  }
}

# One operator web application role per Agent Space.
resource "aws_iam_role" "operator" {
  for_each = var.agent_spaces

  name_prefix        = "DevOpsAgentRole-WebappAdmin-"
  description        = "Operator web application role for ${each.value.application_name}"
  assume_role_policy = data.aws_iam_policy_document.operator_assume_role.json

  tags = local.agent_space_tags[each.key]
}

resource "aws_iam_role_policy_attachment" "operator_access" {
  for_each = var.agent_spaces

  role       = aws_iam_role.operator[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AIDevOpsOperatorAppAccessPolicy"
}
