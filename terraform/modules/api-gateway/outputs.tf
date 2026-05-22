output "api_endpoint" { value = "${aws_api_gateway_deployment.prod.invoke_url}/environments" }
output "api_id"       { value = aws_api_gateway_rest_api.idp.id }
