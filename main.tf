locals {
  reader_role          = toset(var.developer_readonly_access ? ["cluster-reader"] : [])
  permissions_boundary = data.aws_iam_policy.permissions_boundary.arn
  tags = merge(
    {
      moduleinstance = "eks/${var.name}",
      name           = var.name
    },
    var.tags
  )

  cwlog_group         = "/${aws_eks_cluster.main.id}/fargate-fluentbit-logs"
  cwlog_stream_prefix = "fargate-logs-"
  default_config = {
    output_conf  = <<-EOF
    [OUTPUT]
      Name cloudwatch_logs
      Match *
      region ${var.region}
      log_group_name ${local.cwlog_group}
      log_stream_prefix ${local.cwlog_stream_prefix}
      auto_create_group true
    EOF
    filters_conf = <<-EOF
    [FILTER]
      Name parser
      Match *
      Key_Name log
      Parser regex
      Preserve_Key True
      Reserve_Data True
    EOF
    parsers_conf = <<-EOF
    [PARSER]
      Name regex
      Format regex
      Regex ^(?<time>[^ ]+) (?<stream>[^ ]+) (?<logtag>[^ ]+) (?<message>.+)$
      Time_Key time
      Time_Format %Y-%m-%dT%H:%M:%S.%L%z
      Time_Keep On
      Decode_Field_As json message
    EOF
  }

  config = merge(
    local.default_config
  )
}
data "aws_iam_policy" "permissions_boundary" {
  name = "DcpPermissionsBoundary"
}
data "tls_certificate" "main" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
data "aws_vpc" "main" {
  id = var.vpc_id
}

resource "aws_iam_role" "main" {
  name                 = "${var.name}-role"
  permissions_boundary = local.permissions_boundary
  tags                 = local.tags

  assume_role_policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Effect : "Allow"
        Principal : {
          Service : "eks.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "main" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.main.name
}

resource "aws_security_group" "main" {
  name        = "${var.name}-sg"
  description = "Allow TLS and local EKS comms"
  vpc_id      = var.vpc_id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [data.aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [data.aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "port 80 from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [data.aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [data.aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description = "internal"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}

resource "aws_eks_cluster" "main" {
  name     = var.name
  version  = var.cluster_version
  role_arn = aws_iam_role.main.arn
  tags     = local.tags

  encryption_config {
    provider {
      key_arn = var.encryption_key
    }
    resources = ["secrets"]
  }
  enabled_cluster_log_types = ["api", "scheduler", "controllerManager"]

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = contains(["public"], var.api_server_endpoint) ? true : false
    public_access_cidrs     = var.api_server_allow_cidr
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.main.id]
  }

  depends_on = [aws_iam_role_policy_attachment.main]
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "drones-default"
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


# Fargate
resource "aws_iam_role" "fargate" {
  name                 = "${var.name}-fargate"
  permissions_boundary = local.permissions_boundary
  tags                 = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fargate" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate.name
}
resource "aws_iam_role_policy_attachment" "fargate_logs" {
  policy_arn = aws_iam_policy.fargate_logs.arn
  role       = aws_iam_role.fargate.name
}

resource "aws_iam_policy" "fargate_logs" {
  name = "${var.name}-fargate-logs"
  tags = local.tags

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "logs:CreateLogStream",
        "logs:CreateLogGroup",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Resource" : "*"
    }]
  })
}


resource "aws_eks_fargate_profile" "main" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "default"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.private_subnet_ids
  tags                   = local.tags

  selector {
    namespace = "*"
  }

  depends_on = [
    aws_iam_role_policy_attachment.fargate,
    kubernetes_config_map.rbac,
  ]
}

resource "aws_eks_addon" "main" {
  addon_name                  = "coredns"
  addon_version               = "v1.10.1-eksbuild.4"
  cluster_name                = aws_eks_cluster.main.name
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags

  configuration_values = jsonencode({
    computeType : "Fargate"
  })

  depends_on = [aws_eks_fargate_profile.main]
}

resource "helm_release" "metrics_server" {
  name = "metrics-server"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.10.0"

  depends_on = [
    aws_eks_fargate_profile.main,
    kubernetes_config_map.rbac,
  ]
}

resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.main.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = "aws-observability"
    labels = {
      "aws-observability" = "enabled"
      "environment"       = local.tags["environment"]
      "v"                 = local.tags["v"]
      "project"           = local.tags["project"]
      "deployment"        = "terraform"
      "service"           = var.service
    }
    annotations = {}
  }
}

resource "kubernetes_namespace" "dynatrace" {
  metadata {
    name = "dynatrace"
    labels = {
      "aws-observability" = "enabled"
      "environment"       = local.tags["environment"]
      "v"                 = local.tags["v"]
      "project"           = local.tags["project"]
      "deployment"        = "terraform"
      "service"           = var.service
    }
    annotations = {}
  }
}

resource "kubernetes_config_map" "aws_logging" {
  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.observability.id
  }

  data = {
    "parsers.conf" = local.config["parsers_conf"]
    "filters.conf" = local.config["filters_conf"]
    "output.conf"  = local.config["output_conf"]
  }
}