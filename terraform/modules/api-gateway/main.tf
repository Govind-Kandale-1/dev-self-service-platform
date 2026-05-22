resource "aws_api_gateway_rest_api" "idp" {
  name        = "${var.project}-api"
  description = "IDP environment request API"
  tags        = var.tags
}

resource "aws_api_gateway_resource" "environments" {
  rest_api_id = aws_api_gateway_rest_api.idp.id
  parent_id   = aws_api_gateway_rest_api.idp.root_resource_id
  path_part   = "environments"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.idp.id
  resource_id   = aws_api_gateway_resource.environments.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.idp.id
  resource_id   = aws_api_gateway_resource.environments.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id             = aws_api_gateway_rest_api.idp.id
  resource_id             = aws_api_gateway_resource.environments.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.orchestrator_invoke_arn
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.idp.id
  resource_id = aws_api_gateway_resource.environments.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.idp.id
  resource_id = aws_api_gateway_resource.environments.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.idp.id
  resource_id = aws_api_gateway_resource.environments.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_integration.options]
}

resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.idp.id
  stage_name  = "prod"
  depends_on  = [
    aws_api_gateway_integration.post,
    aws_api_gateway_integration_response.options,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.orchestrator_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.idp.execution_arn}/*/*"
}
