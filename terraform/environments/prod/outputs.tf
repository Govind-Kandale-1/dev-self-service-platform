output "vpc_id"                        { value = module.vpc.vpc_id }
output "eks_cluster_name"              { value = module.eks.cluster_name }
output "eks_cluster_endpoint"          { value = module.eks.cluster_endpoint }
output "environments_table"            { value = aws_dynamodb_table.environments.name }
output "terraform_namespace_project"   { value = module.codebuild.terraform_namespace_project }
output "ansible_namespace_project"     { value = module.codebuild.ansible_namespace_project }
