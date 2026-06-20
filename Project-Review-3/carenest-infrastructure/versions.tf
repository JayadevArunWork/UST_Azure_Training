terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.110.0"
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
    machine_learning {
      # This ensures that next time you destroy, it purges immediately
      purge_soft_deleted_workspace_on_destroy = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = "9df14662-7d45-4e90-8102-79f159cee3ed"
}



provider "random" {}

provider "time" {}