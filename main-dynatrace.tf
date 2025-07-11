# resource "helm_release" "dynatrace" {
#   name = "dynatrace"

#   repository = "https://raw.githubusercontent.com/Dynatrace/dynatrace-operator/main/config/helm/repos/stable"
#   chart      = "dynatrace-operator"
#   namespace  = "dynatrace"

#   dynamic "set" {
#     for_each = {
#       "clusterName"                                               = aws_eks_cluster.main.id
#       "controllerConfig.featureGates.SubnetsClusterTagCheck"      = false
#       "podDisruptionBudget.maxUnavailable"                        = 1
#       "region"                                                    = var.region
#       "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = aws_iam_role.dynatrace.arn
#       "serviceAccount.name"                                       = "dynatrace-operator"
#       "vpcId"                                                     = var.vpc_id
#       "apiToken"                                                  = var.dynatrace_api_token
#     }

#     content {
#       name  = set.key
#       value = set.value
#     }
#   }

#   depends_on = [
#     aws_eks_addon.main,
#     aws_iam_role_policy_attachment.dynatrace,
#   ]
# }

resource "helm_release" "dynatrace_operator" {
  count = 1

  atomic    = true
  chart     = "${path.module}/charts/dynatrace-operator"
  name      = "dynatrace-operator"
  namespace = "dynatrace"

  set_sensitive {
    name  = "apiToken"
    value = var.dynatrace_api_token
  }
}

resource "helm_release" "dynatrace_application_monitoring" {
  count = 1

  atomic    = true
  chart     = "${path.module}/charts/dynatrace-application-monitoring"
  name      = "dynatrace-application-monitoring"
  namespace = "dynatrace"

  set {
    name  = "environmentId"
    value = var.dynatrace_environment_id
  }

  depends_on = [helm_release.dynatrace_operator]
}

data "aws_iam_policy_document" "dynatrace" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:dynatrace"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.main.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "dynatrace" {
  name                 = "${var.short-name}Dynatrace"
  assume_role_policy   = data.aws_iam_policy_document.dynatrace.json
  permissions_boundary = local.permissions_boundary
  tags                 = local.tags
}

resource "aws_iam_policy" "dynatrace" {
  name = "${var.short-name}Dynatrace"

  #tfsec:ignore:aws-iam-no-policy-wildcards
  policy = templatefile("${path.module}/templates/dynatrace-iam-policy.tpl", {
    register = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "dynatrace" {
  role       = aws_iam_role.dynatrace.name
  policy_arn = aws_iam_policy.dynatrace.arn
}