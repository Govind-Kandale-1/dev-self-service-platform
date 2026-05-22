variable "project"          { type = string }
variable "tfstate_bucket"   { type = string }
variable "eks_cluster_name" { type = string }
variable "tags"             { type = map(string); default = {} }
