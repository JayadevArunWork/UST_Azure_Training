terraform {
  backend "azurerm" {
    resource_group_name  = "jd-carenest-tfstate-rg"
    storage_account_name = "jdcarenesttfstate"
    container_name       = "tfstate"
    key                  = "jd-carenest.terraform.tfstate"
  }
}