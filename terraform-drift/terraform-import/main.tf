terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.38"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "jd-drift-rg"
  location = "Sweden Central"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "jd-drift-vnet"
  location            = "Sweden Central"
  resource_group_name = "jd-drift-rg"
  address_space       = ["10.0.0.0/16"]

  subnet {
    name             = "default"
    address_prefixes = ["10.0.0.0/24"]
  }
}