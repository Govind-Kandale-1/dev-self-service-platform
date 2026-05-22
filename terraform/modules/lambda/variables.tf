variable "project" { type = string }
variable "tags"    { type = map(string); default = {} }

variable "functions" {
  type = map(object({
    timeout        = number
    memory         = number
    policy_actions = list(string)
    env_vars       = map(string)
  }))
}
