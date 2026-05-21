variable "resource_group_name" {
  default = "myResourceGroup"
}

variable "location" {
  default = "Central India"
}

variable "vnet_name" {
  default = "myVNet"
}

variable "subnet_name" {
  default = "mySubnet"
}

variable "vm_name" {
  default = "myLinuxVM"
}

variable "vm_size" {
  default = "Standard_D2s_v3"
}

variable "admin_username" {
  default = "jayadevazure"
}

variable "admin_password" {
  default   = "JDkittu#2003AZ"
  sensitive = true
} 