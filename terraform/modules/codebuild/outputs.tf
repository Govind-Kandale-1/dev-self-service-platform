output "terraform_namespace_project" { value = aws_codebuild_project.terraform_namespace.name }
output "ansible_namespace_project"   { value = aws_codebuild_project.ansible_namespace.name }
output "codebuild_role_arn"          { value = aws_iam_role.codebuild.arn }
