variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vmss_id" {
  type = string
}

variable "vmss_name" {
  type = string
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