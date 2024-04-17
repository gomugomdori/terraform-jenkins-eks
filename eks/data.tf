data "aws_availability_zones" "azs" {}

# https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2009
data "aws_eks_cluster" "default" {
  name       = module.test-eks-cluster.cluster_name
  depends_on = [module.test-eks-cluster]
}

data "aws_eks_cluster_auth" "default" {
  name       = module.test-eks-cluster.cluster_name
  depends_on = [module.test-eks-cluster]
}
