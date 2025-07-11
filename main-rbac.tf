resource "kubernetes_cluster_role" "rbac" {
  for_each = local.reader_role

  metadata {
    name = each.value
  }

  rule {
    api_groups = ["*"]
    resources  = ["deployments", "configmaps", "pods", "secrets", "services", "namespaces", "serviceaccounts"]
    verbs      = ["get", "list", "watch", "describe"]
  }
}

resource "kubernetes_cluster_role_binding" "rbac" {
  for_each = local.reader_role

  metadata {
    name = "cluster-reader-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = each.value
  }

  subject {
    kind      = "Group"
    name      = "custom:reader"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_config_map" "rbac" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = join("", concat([<<-EOT
        - groups:
          - system:bootstrappers
          - system:nodes
          - system:node-proxier
          rolearn: ${aws_iam_role.fargate.arn}
          username: system:node:{{SessionName}}
        - groups:
          - system:masters
          rolearn: arn:aws:iam::${var.account_id}:role/administrator-eu-west-2
          username: devops-role-user
        - groups:
          - system:masters
          rolearn: arn:aws:iam::${var.account_id}:role/gitlab-runner-role
          username: gitlab-runner-role
    EOT
      ], var.developer_readonly_access ? [<<-EOT
        - groups:
          - custom:reader
          rolearn: ${var.dev-role-arn}
          username: developer-role-user
    EOT
    ] : []))
  }
}