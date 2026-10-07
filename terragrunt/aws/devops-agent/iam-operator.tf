data "aws_iam_policy_document" "operator_assume_role" {
  statement {
    sid     = "AllowAWSDevOpsAgentOperatorApp"
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
