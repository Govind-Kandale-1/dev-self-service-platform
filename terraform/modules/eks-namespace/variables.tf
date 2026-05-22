variable "env_id"       { type = string }
variable "team"         { type = string }
variable "project"      { type = string }
variable "cpu_limit"    { type = string; default = "2" }
variable "memory_limit" { type = string; default = "2Gi" }
variable "max_pods"     { type = string; default = "20" }
