terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "url-shortener"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

module "app" {
  source              = "../../modules/url-shortener"
  project             = "url-shortener"
  environment         = "dev"
  lambda_source_dir   = "${path.root}/../../app/src"
  index_template_path = "${path.root}/../../frontend/index.html.tftpl"
}
