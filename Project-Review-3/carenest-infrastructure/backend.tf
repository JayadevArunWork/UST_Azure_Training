terraform {
  backend "azurerm" {
    resource_group_name  = "jd-carenest-new-tfstate-rg"
    storage_account_name = "jdcarenestnewtfstate"
    container_name       = "tfstate"
    key                  = "jd-carenest-new.terraform.tfstate"
  }
}