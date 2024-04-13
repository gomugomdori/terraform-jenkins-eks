terraform {
  backend "s3" {
    bucket = "gom-terraform-jenkins-eks"
    key    = "eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
