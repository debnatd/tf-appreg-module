terraform {
  required_version = ">= 1.9"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.7.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~>0.13.1"
    }
  }
}