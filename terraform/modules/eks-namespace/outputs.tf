output "namespace"          { value = kubernetes_namespace.this.metadata[0].name }
output "service_account"    { value = kubernetes_service_account.this.metadata[0].name }
