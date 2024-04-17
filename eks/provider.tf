provider "aws" {
  region = "ap-northeast-2"
}

# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.default.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
#   #  token                  = data.aws_eks_cluster_auth.default.token

#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.name]
#     command     = "aws"
#   }
# }

provider "kubernetes" {
  host                   = module.test-eks-cluster.cluster_endpoint
  token                  = data.aws_eks_cluster_auth.default.token
  cluster_ca_certificate = base64decode(module.test-eks-cluster.cluster_certificate_authority_data)
}

# provider "helm" {
#   kubernetes {
#     host                   = data.aws_eks_cluster.default.endpoint
#     cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
#     exec {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.name]
#       command     = "aws"
#     }
#   }
# }



provider "helm" {
  kubernetes {
    host                   = module.test-eks-cluster.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.default.token
    cluster_ca_certificate = base64decode(module.test-eks-cluster.cluster_certificate_authority_data)
  }
}
