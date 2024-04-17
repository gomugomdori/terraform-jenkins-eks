# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "jenkins-vpc"
  cidr = var.vpc_cidr

  azs            = data.aws_availability_zones.azs.names
  public_subnets = var.public_subnets

  #  enable_nat_gateway = true
  #  enable_vpn_gateway = true
  enable_dns_hostnames = true

  tags = {
    Name        = "jenkins-vpc"
    Terraform   = "true"
    Environment = "dev"
  }
}

# SG
module "sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "jenkins-sg"
  description = "Security Group for Jenkins Server"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "HTTP"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags = {
    Name = "jenkins-sg"
  }
}

# IAM
resource "aws_iam_policy" "policy_for_kubectl" {
  name        = "policy_for_kubectl"
  description = "IAM policy for EC2 to manage EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:ListTagsForResource",
          "eks:DescribeFargateProfile",
          "eks:ListFargateProfiles",
          "eks:ListUpdates"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
    ]
  })
}

resource "aws_iam_role" "role_for_kubectl" {
  name = "role_for_kubectl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "policy_attachment_for_kubectl" {
  role       = aws_iam_role.role_for_kubectl.name
  policy_arn = aws_iam_policy.policy_for_kubectl.arn
}

resource "aws_iam_instance_profile" "instance_profile_for_kubectl" {
  name = "instance_profile_for_kubectl"
  role = aws_iam_role.role_for_kubectl.name
}

# EC2
module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "Jenkins-Server"

  ami                         = data.aws_ami.example.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  monitoring                  = true
  vpc_security_group_ids      = [module.sg.security_group_id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  user_data                   = file("jenkins-install.sh")
  availability_zone           = data.aws_availability_zones.azs.names[0]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile_for_kubectl.name


  tags = {
    Name        = "Jenkins-Server"
    Terraform   = "true"
    Environment = "dev"
  }
}
