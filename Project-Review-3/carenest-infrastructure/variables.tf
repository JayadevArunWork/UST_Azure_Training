variable "project_name" {
  type        = string
  description = "Base name for resources"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "owner" {
  type        = string
  description = "Owner of the resources"
}

variable "kubernetes_version" {
  type        = string
  description = "AKS Kubernetes version"
}

variable "system_node_vm_size" {
  type        = string
  description = "VM size for AKS system node pool"
}

variable "app_node_vm_size" {
  type        = string
  description = "VM size for AKS application node pool"
}

variable "app_node_min_count" {
  type        = number
  description = "Minimum nodes for AKS application node pool"
}

variable "app_node_max_count" {
  type        = number
  description = "Maximum nodes for AKS application node pool"
}

variable "cosmos_throughput" {
  type        = number
  description = "Cosmos DB RU throughput"
}

variable "acr_sku" {
  type        = string
  description = "ACR SKU"
}

variable "ops_email" {
  type        = string
  description = "Email address for operational alerts"
}