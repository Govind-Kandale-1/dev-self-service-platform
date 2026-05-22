variable "project"     { type = string }
variable "lambda_arns" { type = map(string) }
variable "tags"        { type = map(string); default = {} }
