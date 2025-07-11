locals {
  permissions_boundary = data.aws_iam_policy.permissions_boundary.arn
  app                  = lower(var.app)

  tags = merge(
    {
      Environment    = var.environment
      ModuleInstance = "eks-service-account/${local.app}"
      name           = var.cluster_name
    },
    var.tags
  )
}


resource "aws_iam_role" "main" {
  name                 = "EKSServiceAccount-${local.app}"
  permissions_boundary = local.permissions_boundary
  tags                 = local.tags

  assume_role_policy = jsonencode({
    Statement = [
      {
        Action : "sts:AssumeRoleWithWebIdentity"
        Condition : {
          StringEquals : {
            "${var.oidc_provider.url}:aud" = "sts.amazonaws.com"
            "${var.oidc_provider.url}:sub" = "system:serviceaccount:${var.namespace}:${local.app}"
          }
        }
        Effect : "Allow"
        Principal : {
          Federated : var.oidc_provider.arn
        },
      },
      {
        Action : "sts:AssumeRoleWithWebIdentity"
        Condition : {
          StringEquals : {
            "${var.oidc_provider.url}:aud" = "sts.amazonaws.com"
            "${var.oidc_provider.url}:sub" = "system:serviceaccount:${var.namespace}:external-secrets-provider-aws"
          }
        }
        Effect : "Allow"
        Principal : {
          Federated : var.oidc_provider.arn
        },
      }
    ]
    Version : "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "main" {
  for_each = var.policy_arns

  role       = aws_iam_role.main.name
  policy_arn = each.value
}

resource "kubernetes_service_account" "main" {
  metadata {
    name      = local.app
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.main.arn
    }
  }
}
