terraform {
  backend "s3" {
    bucket         = "bilarn-eks-aws-bucket1"
    region         = "us-east-1"
    key            = "aws-eks-mtire-devsec-project/terraform.tfstate"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
  required_version = ">=0.13.0"
  required_providers {
    aws = {
      version = ">= 2.7.0"
      source  = "hashicorp/aws"
    }
  }
}