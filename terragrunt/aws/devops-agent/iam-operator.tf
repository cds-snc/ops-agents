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

resource "aws_iam_role" "operator" {
  name_prefix        = "DevOpsAgentRole-WebappAdmin-"
  description        = "Operator web application role for ${var.application_name}"
  assume_role_policy = data.aws_iam_policy_document.operator_assume_role.json

  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "operator_access" {
  role       = aws_iam_role.operator.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AIDevOpsOperatorAppAccessPolicy"
}