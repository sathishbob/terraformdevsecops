terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.67.0"
    }
  }
  backend "s3" {
    encrypt        = true
    bucket         = "sathis-terraform-state-0810"
    region         = "ap-southeast-1"
    dynamodb_table = "training-terraform-lock"
    key            = "terraform.tfstate"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-1"
}
