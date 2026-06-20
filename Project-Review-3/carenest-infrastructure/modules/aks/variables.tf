variable "project_name" {}
variable "location" {}
variable "resource_group_name" {}
variable "kubernetes_version" {}
variable "system_node_vm_size" {}
variable "app_node_vm_size" {}
variable "app_node_min_count" {}
variable "app_node_max_count" {}
variable "aks_subnet_id" {}
variable "acr_id" {}
variable "keyvault_id" {}
variable "log_analytics_workspace_id" {}
variable "monitor_workspace_id" {}
variable "tags" { type = map(string) }
variable "appgw_id" { type = string }
