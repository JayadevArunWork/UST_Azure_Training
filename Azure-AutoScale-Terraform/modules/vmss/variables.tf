variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vmss_name" {
  type = string
}

variable "vmss_sku" {
  type = string
}

variable "vmss_instances" {
  type = number
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "subnet_id" {
  type = string
}

variable "lb_backend_pool_id" {
  type = string
}

variable "nsg_id" {
  type = string
}