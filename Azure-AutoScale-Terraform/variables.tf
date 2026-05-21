variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "subnet_name" {
  type = string
}

variable "subnet_prefix" {
  type = list(string)
}

variable "nsg_name" {
  type = string
}

variable "nat_gw_name" {
  type = string
}

variable "lb_name" {
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

variable "vmss_admin_username" {
  type = string
}

variable "vmss_admin_password" {
  type      = string
  sensitive = true
}

variable "autoscale_min" {
  type = number
}

variable "autoscale_max" {
  type = number
}

variable "scale_out_cpu" {
  type = number
}

variable "scale_in_cpu" {
  type = number
}

variable "servicebus_name" {
  type = string
}

variable "topic_name" {
  type = string
}

variable "subscription_name" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "logic_app_name" {
  type = string
}