terraform {
  required_version = ">= 1.5.0"
  required_providers {
    file = {
      source  = "rancher/file"
      version = ">= 2.4.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    acme = { # used in the access module
      source  = "vancluever/acme"
      version = ">= 2.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.3"
    }
  }
  backend "local" {}
}
