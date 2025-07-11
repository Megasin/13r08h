data "aws_iam_policy_document" "alb" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.main.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "alb" {
  name                 = "${var.short-name}AWSLoadBalancerController"
  assume_role_policy   = data.aws_iam_policy_document.alb.json
  permissions_boundary = local.permissions_boundary
  tags                 = local.tags
}

resource "aws_iam_policy" "alb" {
  name = "${var.short-name}AWSLoadBalancerController"
  /**
   * Policy comes from official documentation available in:
   *   https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
   * and it uses wildcards, so the tfsec rule is being ignored.
   */
  #tfsec:ignore:aws-iam-no-policy-wildcards
  policy = templatefile("${path.module}/templates/alb-controller-iam-policy.tpl", {
    register = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "alb" {
  role       = aws_iam_role.alb.name
  policy_arn = aws_iam_policy.alb.arn
}

resource "helm_release" "alb" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.5.5"

  dynamic "set" {
    for_each = {
      "clusterName"                                               = aws_eks_cluster.main.id
      "controllerConfig.featureGates.SubnetsClusterTagCheck"      = false
      "podDisruptionBudget.maxUnavailable"                        = 1
      "region"                                                    = var.region
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = aws_iam_role.alb.arn
      "serviceAccount.name"                                       = "aws-load-balancer-controller"
      "vpcId"                                                     = var.vpc_id
    }

    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [
    aws_eks_addon.main,
    aws_iam_role_policy_attachment.alb,
  ]
}

resource "helm_release" "echo_server" {
  name = "echo-server"

  repository = "https://ealenn.github.io/charts"
  chart      = "echo-server"
  namespace  = "kube-system"
  version    = "0.5.0"

  dynamic "set" {
    for_each = {
      "application.enable.environment"                                   = false
      "application.logs.ignore.ping"                                     = true
      "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name" = var.alb_ingress_group
      "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"       = "internal"
      "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"  = "ip"
      "ingress.annotations.kubernetes\\.io/ingress\\.class"              = "alb"
      "ingress.enabled"                                                  = true
      "ingress.hosts[0].host"                                            = ""
      "ingress.hosts[0].paths[0]"                                        = "/echo"
      "replicaCount"                                                     = var.echo_server_replica_count
    }

    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [helm_release.alb]
}

# data "aws_lb" "alb" {
#   tags = {
#     "elbv2.k8s.aws/cluster" = aws_eks_cluster.main.name
#     "ingress.k8s.aws/stack" = var.alb_ingress_group
#   }

#   depends_on = [helm_release.echo_server]
# }

# data "aws_lb_listener" "alb" {
#   load_balancer_arn = data.aws_lb.alb.arn
#   port              = 80
# }
