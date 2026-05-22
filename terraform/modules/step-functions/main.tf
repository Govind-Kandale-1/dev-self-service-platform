data "aws_iam_policy_document" "sfn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn" {
  name               = "${var.project}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "sfn" {
  role = aws_iam_role.sfn.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = values(var.lambda_arns)
      },
      {
        Effect   = "Allow"
        Action   = [
          "codebuild:StartBuild",
          "codebuild:StopBuild",
          "codebuild:BatchGetBuilds",
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery",
                    "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutResourcePolicy",
                    "logs:DescribeResourcePolicies", "logs:DescribeLogGroups"]
        Resource = "*"
      }
    ]
  })
}

locals {
  definition = templatefile("${path.module}/../../step-functions/workflow.asl.json", {
    entra_lambda_arn         = var.lambda_arns["entra"]
    grafana_lambda_arn       = var.lambda_arns["grafana"]
    update_status_lambda_arn = var.lambda_arns["update-status"]
    notify_lambda_arn        = var.lambda_arns["notify"]
  })
}

resource "aws_sfn_state_machine" "idp" {
  name     = "${var.project}-provisioner"
  role_arn = aws_iam_role.sfn.arn
  definition = local.definition
  tags     = var.tags
}
