data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each           = var.functions
  name               = "${var.project}-${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "this" {
  for_each = var.functions
  role     = aws_iam_role.this[each.key].id
  policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = each.value.policy_actions
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  for_each   = var.functions
  role       = aws_iam_role.this[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "this" {
  for_each      = var.functions
  function_name = "${var.project}-${each.key}"
  role          = aws_iam_role.this[each.key].arn
  runtime       = "python3.12"
  handler       = "main.handler"
  timeout       = each.value.timeout
  memory_size   = each.value.memory

  filename         = "${path.module}/placeholder.zip"
  source_code_hash = filebase64sha256("${path.module}/placeholder.zip")

  environment {
    variables = each.value.env_vars
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

resource "local_file" "placeholder" {
  content  = ""
  filename = "${path.module}/placeholder.zip"

  lifecycle {
    ignore_changes = [content]
  }
}
