terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.110.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.50.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = "5989c502-2330-4d91-b86c-78a102728614"
}

provider "azuread" {
  tenant_id = "d8537334-bc24-4daf-95a8-bf4c9fb14394"
}

provider "random" {}

provider "time" {}