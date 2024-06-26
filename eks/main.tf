# VPC 생성
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks-vpc"
  cidr = var.vpc_cidr

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# EKS 클러스터 생성
module "test-eks-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "test-eks-cluster"
  cluster_version = "1.29"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  enable_irsa = true

  eks_managed_node_group_defaults = {
    disk_size = 50
  }

  eks_managed_node_groups = {
    general = {
      desired_size = 1
      min_size     = 1
      max_size     = 10

      labels = {
        role = "general"
      }

      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
    }

    spot = {
      desired_size = 1
      min_size     = 1
      max_size     = 10

      labels = {
        role = "spot"
      }

      taints = [{
        key    = "market"
        value  = "spot"
        effect = "NO_SCHEDULE"
      }]

      instance_types = ["m5.large"]
      capacity_type  = "SPOT"
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Load Balancer Controller
## Load Balancer Controller IRSA
module "aws_load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.test-eks-cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

## Load Balancer Controller 설치
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.test-eks-cluster.cluster_name
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }

  depends_on = [module.aws_load_balancer_controller_irsa_role]
}

# Argo CD
resource "helm_release" "argocd" {
  name = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  values = [file("argocd-value.yaml")]

  depends_on = [helm_release.aws_load_balancer_controller]
}

# ArgoCD Ingress
resource "kubernetes_ingress_v1" "argo_cd_ingress" {
  metadata {
    name      = "argocd-server-ingress"
    namespace = "argocd"
    annotations = {
      "kubernetes.io/ingress.class"            = "alb"
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"  = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ "HTTP" : 80 }])
      "alb.ingress.kubernetes.io/group.name"   = "gom-ingress"
      "alb.ingress.kubernetes.io/group.order"  = "1"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "argocd.gomugom.site"
      http {
        path {
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
          path      = "/"
          path_type = "Prefix"
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
