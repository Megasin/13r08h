resource "kubernetes_cluster_role" "eso" {
  metadata {
    name = "eso-store-role"
  }

  rule {
    api_groups = ["*"]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch", "describe"]
  }
  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["selfsubjectrulesreviews"]
    verbs      = ["create"]
  }
}

# This block may be required to bind this role if not applied already by helm chart
# resource "kubernetes_cluster_role_binding" "eso_binding" {
#   metadata {
#     name = "eso-role-binding"
#   }
#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "eso-store-role"
#   }
#   subject {
#     kind      = "User"
#     name      = "admin"
#     api_group = "rbac.authorization.k8s.io"
#   }
# }

resource "helm_release" "eso" {
  name = "external-secrets"

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets"

  dynamic "set" {
    for_each = {
      "clusterName"                                          = aws_eks_cluster.main.id
      "controllerConfig.featureGates.SubnetsClusterTagCheck" = false
      "podDisruptionBudget.maxUnavailable"                   = 1
      "region"                                               = var.region
      "vpcId"                                                = var.vpc_id
      "webhook.port"                                         = 10260
    }

    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [
    aws_eks_addon.main
  ]
}

resource "kubernetes_namespace" "eso" {
  metadata {
    name = "external-secrets"
    labels = {
      "environment" = local.tags["environment"]
      "v"           = local.tags["v"]
      "project"     = local.tags["project"]
      "deployment"  = "terraform"
      "service"     = var.service
    }
    annotations = {}
  }
}
