terraform {
  backend "s3" {
    bucket = "gom-terraform-jenkins-eks"
    key    = "jenkins/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
