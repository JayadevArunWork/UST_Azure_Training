variable "resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
  default     = "rg-terraform-depend-demo"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "swedencentral"
}

variable "vnet_name" {
  description = "Name of the virtual network."
  type        = string
  default     = "vnet-terraform-depend-demo"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "foreach_subnets" {
  description = "Two subnets created with for_each."
  type        = map(string)
  default = {
    app-subnet = "10.0.1.0/24"
    db-subnet  = "10.0.2.0/24"
  }
}

variable "count_subnets" {
  description = "Two subnets created with count."
  type = list(object({
    name           = string
    address_prefix = string
  }))
  default = [
    {
      name           = "web-subnet"
      address_prefix = "10.0.3.0/24"
    },
    {
      name           = "mgmt-subnet"
      address_prefix = "10.0.4.0/24"
    }
  ]
}

variable "vm_name" {
  description = "Name of the Linux virtual machine."
  type        = string
  default     = "vm-terraform-demo"
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the Linux VM."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key used to access the Linux VM."
  type        = string
  sensitive   = true
}
