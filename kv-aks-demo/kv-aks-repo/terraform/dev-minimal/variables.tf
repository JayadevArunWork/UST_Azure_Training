variable "subscription_id" {
  description = "Azure subscription used for the minimal development environment."
  type        = string
  default     = "6b01db76-626a-44a2-8119-17682410914a"
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  default     = "83474cb5-f1fa-4d06-906c-e5dad12ce3b9"
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "resource_group_name" {
  type    = string
  default = "rg-sentinel"
}

variable "name_suffix" {
  description = "A globally unique 4-8 character lowercase alphanumeric suffix."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{4,8}$", var.name_suffix))
    error_message = "Use a 4-8 character lowercase alphanumeric suffix."
  }
}

variable "owner" {
  type    = string
  default = "elzabeth"
}

variable "postgres_admin_login" {
  type    = string
  default = "sentineladmin"
}

variable "postgres_admin_password" {
  description = "Supply with TF_VAR_postgres_admin_password. Never commit it."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.postgres_admin_password) >= 8
    error_message = "The PostgreSQL administrator password must be at least 8 characters."
  }
}

variable "postgres_sku_name" {
  description = "Use B_Standard_B2ms if B_Standard_B1ms is unavailable in the selected region."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "aks_node_vm_size" {
  description = "One combined system/workload node pool is used."
  type        = string
  default     = "Standard_D2as_v5"
}

variable "aks_api_authorized_ip_ranges" {
  description = "Optional public CIDRs allowed to reach the AKS API. Leave empty for unrestricted API networking."
  type        = list(string)
  default     = []
}

variable "operator_postgres_ip" {
  description = "Optional single public IPv4 address allowed to connect to PostgreSQL for troubleshooting."
  type        = string
  default     = null
  nullable    = true
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}
