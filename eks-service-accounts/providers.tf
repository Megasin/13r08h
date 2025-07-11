provider "kubernetes" {
  # host                   = local.cluster_endpoint
  # cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
  # exec {
  #   api_version = "client.authentication.k8s.io/v1beta1"
  #   args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.main.name]
  #   command     = "aws"
  # }
  config_path = "~/.kube/config"
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.33.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
  required_version = ">= 1.0"
}