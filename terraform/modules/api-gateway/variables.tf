variable "project"                    { type = string }
variable "orchestrator_invoke_arn"    { type = string }
variable "orchestrator_function_name" { type = string }
variable "tags"                       { type = map(string); default = {} }
