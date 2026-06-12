terraform {
  backend "azurerm" {
    resource_group_name  = "jd-rg-tfstate"
    storage_account_name = "jdsttfstateexample001"
    container_name       = "jdtfstate"
    key                  = "terraform-depend.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

