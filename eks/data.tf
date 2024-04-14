data "aws_availability_zones" "azs" {}

# https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2009
data "aws_eks_cluster" "default" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "default" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}
