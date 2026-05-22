terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

locals {
  namespace = "${var.team}-${var.project}-${var.env_id}"
  labels = {
    "app.kubernetes.io/managed-by" = "idp"
    "idp/team"                     = var.team
    "idp/project"                  = var.project
    "idp/env-id"                   = var.env_id
  }
}

resource "kubernetes_namespace" "this" {
  metadata {
    name   = local.namespace
    labels = local.labels
  }
}

resource "kubernetes_resource_quota" "this" {
  metadata {
    name      = "quota"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = var.cpu_limit
      "requests.memory" = var.memory_limit
      "limits.cpu"      = var.cpu_limit
      "limits.memory"   = var.memory_limit
      "pods"            = var.max_pods
    }
  }
}

resource "kubernetes_limit_range" "this" {
  metadata {
    name      = "limits"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "64Mi"
      }
    }
  }
}

resource "kubernetes_network_policy" "deny_all_ingress" {
  metadata {
    name      = "deny-all-ingress"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "allow_same_namespace" {
  metadata {
    name      = "allow-same-namespace"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    pod_selector {}
    ingress {
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = local.namespace }
        }
      }
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "allow_monitoring" {
  metadata {
    name      = "allow-monitoring"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    pod_selector {}
    ingress {
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "monitoring" }
        }
      }
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = "${var.env_id}-sa"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }
}

resource "kubernetes_role" "developer" {
  metadata {
    name      = "developer"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  rule {
    api_groups = ["", "apps", "batch", "autoscaling"]
    resources  = ["pods", "deployments", "services", "configmaps", "jobs", "cronjobs", "horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/log", "pods/exec"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding" "developer" {
  metadata {
    name      = "developer-binding"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.developer.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.this.metadata[0].name
    namespace = kubernetes_namespace.this.metadata[0].name
  }
}
