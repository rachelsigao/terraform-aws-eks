terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.32.0"
    }
  }

  backend "s3" {
    bucket = "latest-84s-remote-state-dev"
    key    = "roboshop-dev-vpc"
    region = "us-east-1"
    encrypt        = true
    use_lockfile = true
  }
}

# provider "aws" {
#   # Configuration options
#   region = "us-east-1"
# }