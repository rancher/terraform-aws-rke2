terraform {
  required_version = ">= 1.2.0, < 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
    github = {
      source  = "integrations/github"
      version = ">= 5.32, < 5.42"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
  }
}