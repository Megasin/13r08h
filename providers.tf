provider "helm" {
  kubernetes {
    # host                   = aws_eks_cluster.main.endpoint
    # cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    # token                  = data.aws_eks_cluster_auth.main.token
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  # host                   = aws_eks_cluster.main.endpoint
  # cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  # token                  = data.aws_eks_cluster_auth.main.token
  config_path = "~/.kube/config"
}


terraform {
  required_version = ">= 1.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
