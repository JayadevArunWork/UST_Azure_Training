variable "resource_group_name" {
  type = string
}

variable "vmss_id" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "logic_app_id" {
  type = string
}

variable "logic_app_url" {
  type      = string
  sensitive = true
}