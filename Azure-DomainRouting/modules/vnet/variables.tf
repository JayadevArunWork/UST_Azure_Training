variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "vnet_address" {
  type = list(string)
}

variable "appgw_subnet_name" {
  type = string
}

variable "appgw_subnet_prefix" {
  type = list(string)
}

variable "vm_subnet_name" {
  type = string
}

variable "vm_subnet_prefix" {
  type = list(string)
}

variable "bastion_subnet_prefix" {
  type = list(string)
}