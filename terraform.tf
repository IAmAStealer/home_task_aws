terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.63"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8.0"
    }
  }
  backend "s3" {
    bucket = "3a43faa4-955a-4c3d-9579-af96f65a9932"
    key    = "terraform.tfstate"
    region = "eu-west-1"
  }
  required_version = ">= 1.16"
}
