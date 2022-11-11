terraform {
  required_version = ">= 0.13"
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = "0.5.1"
    }
  }
  backend "kubernetes" {
    secret_suffix    = "state-infra"
    config_path      = "~/.kube/config"
  }
}

provider "harvester" {
}