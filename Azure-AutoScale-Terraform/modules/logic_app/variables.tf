variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "logic_app_name" {
  type = string
}

variable "sb_connection_string" {
  type      = string
  sensitive = true
}

variable "topic_name" {
  type = string
}