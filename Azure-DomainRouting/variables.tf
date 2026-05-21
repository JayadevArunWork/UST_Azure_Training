variable "location" {
  type = string
}

variable "rg_name" {
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

variable "nsg_name" {
  type = string
}

variable "nat_gw_name" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "organic_domain" {
  type = string
}

variable "fitness_domain" {
  type = string
}

variable "appgw_name" {
  type = string
}