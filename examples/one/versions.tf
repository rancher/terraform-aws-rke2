terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    acme = {
      source  = "vancluever/acme"
      version = ">= 2.23"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.2"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}
provider "github" {}
